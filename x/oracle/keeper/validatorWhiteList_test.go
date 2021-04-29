package keeper_test

import (
	"testing"

	oracleKeeper "github.com/Sifchain/sifnode/x/oracle/keeper"
	"github.com/Sifchain/sifnode/x/oracle/types"
	"github.com/stretchr/testify/assert"
)

const networkID = 1

func TestKeeper_SetValidatorWhiteList(t *testing.T) {
	ctx, keeper, _, _, _, whitelist, _ := oracleKeeper.CreateTestKeepers(t, 0.7, []int64{3, 7}, "")
	networkDescriptor := types.NewNetworkDescriptor(networkID)
	keeper.SetOracleWhiteList(ctx, networkDescriptor, whitelist)
	vList := keeper.GetOracleWhiteList(ctx, networkDescriptor)
	assert.Equal(t, len(vList.Whitelist), 2)
	assert.True(t, keeper.ExistsOracleWhiteList(ctx, networkDescriptor))
}

func TestKeeper_ValidateAddress(t *testing.T) {
	ctx, keeper, _, _, _, whitelist, _ := oracleKeeper.CreateTestKeepers(t, 0.7, []int64{3, 7}, "")
	addresses := whitelist.GetAllValidators()
	networkDescriptor := types.NewNetworkDescriptor(networkID)

	keeper.SetOracleWhiteList(ctx, networkDescriptor, whitelist)
	assert.True(t, keeper.ValidateAddress(ctx, networkDescriptor, addresses[0]))
	assert.True(t, keeper.ValidateAddress(ctx, networkDescriptor, addresses[1]))
	_, addresses = oracleKeeper.CreateTestAddrs(3)
	assert.False(t, keeper.ValidateAddress(ctx, networkDescriptor, addresses[2]))
}
