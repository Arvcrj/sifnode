package types

import (
	"github.com/Sifchain/sifnode/x/clp"
	"github.com/cosmos/cosmos-sdk/types"
)

type RemoveFaucetFeeDecorator struct{}

func NewRemoveFacuetFeeDecorator() RemoveFaucetFeeDecorator {
	return RemoveFaucetFeeDecorator{}
}

var _ types.AnteDecorator = RemoveFaucetFeeDecorator{}

func (r RemoveFaucetFeeDecorator) AnteHandle(ctx types.Context, tx types.Tx, simulate bool, next types.AnteHandler) (newCtx types.Context, err error) {
	if ctx.ChainID() != "sifchain" && Profile == TESTNET {
		newDecCoin := types.NewDecCoinFromDec(clp.GetSettlementAsset().Symbol, types.NewDec(0))
		ctx = ctx.WithMinGasPrices(types.NewDecCoins(newDecCoin))
	}
	return next(ctx, tx, simulate)
}
