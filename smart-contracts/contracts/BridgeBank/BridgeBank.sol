pragma solidity 0.8.0;

import "./CosmosBank.sol";
import "./EthereumBank.sol";
import "./EthereumWhitelist.sol";
import "./CosmosWhiteList.sol";
import "../Oracle.sol";
import "../CosmosBridge.sol";
import "./BankStorage.sol";
import "./Pausable.sol";

/**
 * @title BridgeBank
 * @dev Bank contract which coordinates asset-related functionality.
 *      CosmosBank manages the minting and burning of tokens which
 *      represent Cosmos based assets, while EthereumBank manages
 *      the locking and unlocking of Ethereum and ERC20 token assets
 *      based on Ethereum. WhiteList records the ERC20 token address 
 *      list that can be locked.
 **/

contract BridgeBank is BankStorage,
    CosmosBank,
    EthereumBank,
    EthereumWhiteList,
    CosmosWhiteList,
    Pausable {
    using SafeERC20 for IERC20;

    bool private _initialized;

    mapping (address => uint8) public contractDecimals;
    mapping (address => string) public contractSymbol;
    mapping (address => string) public contractName;

    /*
     * @dev: Initializer, sets operator
     */
    function initialize(
        address _operatorAddress,
        address _cosmosBridgeAddress,
        address _owner,
        address _pauser
    ) public {
        require(!_initialized, "Init");

        CosmosWhiteList._cosmosWhitelistInitialize();
        Pausable._pausableInitialize(_pauser);

        operator = _operatorAddress;
        cosmosBridge = _cosmosBridgeAddress;
        owner = _owner;
        _initialized = true;
    }

    /*
     * @dev: Modifier to restrict access to operator
     */
    modifier onlyOperator() {
        require(msg.sender == operator, "!operator");
        _;
    }

    /*
     * @dev: Modifier to restrict access to operator
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    /*
     * @dev: Modifier to restrict access to the cosmos bridge
     */
    modifier onlyCosmosBridge() {
        require(
            msg.sender == cosmosBridge,
            "!cosmosbridge"
        );
        _;
    }

    /*
     * @dev: Modifier to only allow valid sif addresses
     */
    modifier validSifAddress(bytes memory _sifAddress) {
        require(_sifAddress.length == 42, "Invalid len");
        require(verifySifPrefix(_sifAddress) == true, "Invalid sif address");
        _;
    }

    /*
     * @dev: Set the token address in whitelist
     *
     * @param _token: ERC 20's address
     * @param _inList: set the _token in list or not
     * @return: new value of if _token in whitelist
     */
    function setTokenInCosmosWhiteList(address _token, bool _inList)
        internal returns (bool)
    {
        _cosmosTokenWhiteList[_token] = _inList;
        emit LogWhiteListUpdate(_token, _inList);
        return _inList;
    }

    function changeOwner(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "invalid address");
        owner = _newOwner;
    }

    function changeOperator(address _newOperator) public onlyOperator {
        require(_newOperator != address(0), "invalid address");
        operator = _newOperator;
    }

    /*
     * @dev: function to validate if a sif address has a correct prefix
     */
    function verifySifPrefix(bytes memory _sifAddress) public pure returns (bool) {
        bytes3 sifInHex = 0x736966;

        for (uint256 i = 0; i < sifInHex.length; i++) {
            if (sifInHex[i] != _sifAddress[i]) {
                return false;
            }
        }
        return true;
    }

    /*
     * @dev: Creates a new BridgeToken
     *
     * @param _symbol: The new BridgeToken's symbol
     * @return: The new BridgeToken contract's address
     */
    function createNewBridgeToken(string calldata _symbol)
        external
        onlyCosmosBridge
        returns (address)
    {
        address newTokenAddress = deployNewBridgeToken(_symbol);
        setTokenInCosmosWhiteList(newTokenAddress, true);

        return newTokenAddress;
    }

    /*
     * @dev: Creates a new BridgeToken
     *
     * @param _symbol: The new BridgeToken's symbol
     * @return: The new BridgeToken contract's address
     */
    function addExistingBridgeToken(
        address _contractAddress    
    ) external onlyOwner returns (bool) {
        return setTokenInCosmosWhiteList(_contractAddress, true);
    }

    function handleUnpeg(
        address payable _ethereumReceiver,
        address _tokenAddress,
        uint256 _amount   
    ) external onlyCosmosBridge whenNotPaused {
        // if this is a bridge controlled token, then we need to mint
        if (getCosmosTokenInWhiteList(_tokenAddress)) {
            return mintNewBridgeTokens(
                _ethereumReceiver,
                _tokenAddress,
                _amount
            );
        } else {
            // if this is an external token, we unlock
            return unlock(_ethereumReceiver, _tokenAddress, _amount);
        }
    }


    function getDecimals(address _token) private returns (uint8) {
        uint8 decimals = contractDecimals[_token];
        if (decimals > 0) {
            return decimals;
        }

        try BridgeToken(_token).decimals() returns (uint8 _decimals) {
            decimals = _decimals;
            contractDecimals[_token] = _decimals;
        } catch {
            // if we can't access the decimals function of this token,
            // assume that it has 18 decimals
            decimals = 18;
        }

        return decimals;
    }


    /*
     * @dev: Burns BridgeTokens representing native Cosmos assets.
     *
     * @param _recipient: bytes representation of destination address.
     * @param _token: token address in origin chain (0x0 if ethereum)
     * @param _amount: value of deposit
     */
    function burn(
        bytes calldata _recipient,
        address _token,
        uint256 _amount
    ) external validSifAddress(_recipient) onlyCosmosTokenWhiteList(_token) whenNotPaused {
        // burn the tokens
        BridgeToken(_token).burnFrom(msg.sender, _amount);
        
        // decimals defaults to 18 if call to decimals fails
        uint8 decimals = getDecimals(_token);

        lockBurnNonce = lockBurnNonce + 1;
        uint256 _chainid = getChainID();

        emit LogBurn(
            msg.sender,
            _recipient,
            _token,
            _amount,
            lockBurnNonce,
            _chainid,
            decimals
        );
    }

    function getName(address _token) private returns (string memory) {
        string memory name = contractName[_token];

        // check to see if we already have this name stored in the smart contract
        if (keccak256(abi.encodePacked(name)) != keccak256(abi.encodePacked(""))) {
            return name;
        }

        try BridgeToken(_token).name() returns (string memory _name) {
            name = _name;
            contractName[_token] = _name;
        } catch {
            // if we can't access the decimals function of this token,
            // assume that it has 18 decimals
            name = "";
        }

        return name;
    }

    function getSymbol(address _token) private returns (string memory) {
        string memory symbol = contractSymbol[_token];

        // check to see if we already have this name stored in the smart contract
        if (keccak256(abi.encodePacked(symbol)) != keccak256(abi.encodePacked(""))) {
            return symbol;
        }

        try BridgeToken(_token).symbol() returns (string memory _symbol) {
            symbol = _symbol;
            contractSymbol[_token] = _symbol;
        } catch {
            // if we can't access the decimals function of this token,
            // assume that it has 18 decimals
            symbol = "";
        }

        return symbol;
    }


    /*
     * @dev: Locks received Ethereum/ERC20 funds.
     *
     * @param _recipient: bytes representation of destination address.
     * @param _token: token address in origin chain (0x0 if ethereum)
     * @param _amount: value of deposit
     */
    function lock(
        bytes calldata _recipient,
        address _token,
        uint256 _amount
    ) external validSifAddress(_recipient) whenNotPaused {
        {
            IERC20 tokenToTransfer = IERC20(_token);
            // lock tokens
            tokenToTransfer.safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );
        }

        // decimals defaults to 18 if call to decimals fails
        uint8 decimals = getDecimals(_token);

        // Get name and symbol
        string memory name = getName(_token);
        string memory symbol = getSymbol(_token);

        lockBurnNonce = lockBurnNonce + 1;
        uint256 _chainid = getChainID();
        {
            emit LogLock(
                msg.sender,
                _recipient,
                _token,
                _amount,
                lockBurnNonce,
                _chainid,
                decimals,
                symbol,
                name
            );
        }
    }

    /**
     *
     * @param _recipient: recipient's Ethereum address
     * @param _tokenAddress: token contract address
     * @param _amount: wei amount or ERC20 token count
     */
    function unlock(
        address payable _recipient,
        address _tokenAddress,
        uint256 _amount
    ) public onlyCosmosBridge whenNotPaused {
        unlockFunds(_recipient, _tokenAddress, _amount);
    }

    /*
    * @dev fallback function for ERC223 tokens so that we can receive these tokens in our contract
    * Don't need to do anything to handle these tokens
    */
    function tokenFallback(address _from, uint _value, bytes memory _data) public {}
}
