package keeper

import (
	"testing"

	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestSetEthGasPrice(t *testing.T) {
	ctx, keeper, _, _, _, _ := CreateTestKeepers(t, 0.7, []int64{3, 3}, "")

	keeper.SetEthGasPrice(ctx, sdk.NewInt(100))
	EthGasPrice := keeper.GetEthGasPrice(ctx)
	assert.Equal(t, *EthGasPrice, sdk.NewInt(100))
}

func TestIsEthGasPriceSet(t *testing.T) {
	ctx, keeper, _, _, _, _ := CreateTestKeepers(t, 0.7, []int64{3, 7}, "")
	isEthGasPriceSet := keeper.IsEthGasPriceSet(ctx)
	require.Equal(t, isEthGasPriceSet, false)
}

func TestSetGasMultiplier(t *testing.T) {
	ctx, keeper, _, _, _, _ := CreateTestKeepers(t, 0.7, []int64{3, 3}, "")

	keeper.SetGasMultiplier(ctx, sdk.NewInt(100))
	GasMultiplier := keeper.GetGasMultiplier(ctx)
	assert.Equal(t, *GasMultiplier, sdk.NewInt(100))
}

func TestIsGasMultiplierSet(t *testing.T) {
	ctx, keeper, _, _, _, _ := CreateTestKeepers(t, 0.7, []int64{3, 7}, "")
	isGasMultiplierSet := keeper.IsGasMultiplierSet(ctx)
	require.Equal(t, isGasMultiplierSet, false)
}
