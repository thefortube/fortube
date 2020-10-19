#!/bin/bash
set -x
set -e 

source .env.rinkeby.stg

# This is for testnet - deploy only

START=`date +%s`

print_progress () {
  printf "\e[0;33m$1\e[0m\n"
}

print_success () {
  printf "\e[4;32m$1\e[0m\n"
}

npx oz compile --solc-version=0.6.4 --optimizer on

npx oz session --network $NETWORK

PRICE_ORACLES=`npx oz deploy -k regular -n $NETWORK PriceOracles`
print_progress "PRICE_ORACLES = $PRICE_ORACLES"
echo "PRICE_ORACLES=$PRICE_ORACLES" >> deployed.stg.env

IRM=`npx oz deploy -k regular -n $NETWORK InterestRateModel 20000000000000000 500000000000000000`
print_progress "IRM = $IRM"
echo "IRM=$IRM" >> deployed.stg.env

MSIGN=`npx oz deploy -k regular -n $NETWORK Msign 3 [$OWNER1,$OWNER2,$OWNER3]`
print_progress "MSIGN = $MSIGN"
echo "MSIGN=$MSIGN" >> deployed.stg.env

BANK_CONTROLLER=`npx oz create -n $NETWORK BankController --init initialize --args $MSIGN`
print_progress "BANK_CONTROLLER = $BANK_CONTROLLER"
echo "BANK_CONTROLLER=$BANK_CONTROLLER" >> deployed.stg.env

BANK=`npx oz create -n $NETWORK Bank --init initialize --args $BANK_CONTROLLER,$MSIGN`
print_progress "BANK = $BANK"
echo "BANK=$BANK" >> deployed.stg.env

FETH=`npx oz create -n $NETWORK FToken --init initialize --args 1e18,$BANK_CONTROLLER,$IRM,$ETH,$BANK,1e18,\"ForTube\ ETH\",\"fETH\",18`
print_progress "FETH = $FETH"
echo "FETH=$FETH" >> deployed.stg.env

FHBTC=`npx oz create -n $NETWORK FToken --init initialize --args 1e18,$BANK_CONTROLLER,$IRM,$HBTC,$BANK,1e18,\"ForTube\ HBTC\",\"fHBTC\",18`
print_progress "FHBTC = $FHBTC"
echo "FHBTC=$FHBTC" >> deployed.stg.env

FWBTC=`npx oz create -n $NETWORK FToken --init initialize --args 1e8,$BANK_CONTROLLER,$IRM,$WBTC,$BANK,1e18,\"ForTube\ WBTC\",\"fWBTC\",18`
print_progress "FWBTC = $FWBTC"
echo "FWBTC=$FWBTC" >> deployed.stg.env

FUSDT=`npx oz create -n $NETWORK FToken --init initialize --args 1e6,$BANK_CONTROLLER,$IRM,$USDT,$BANK,1e18,\"ForTube\ USDT\",\"fUSDT\",18`
print_progress "FUSDT = $FUSDT"
echo "FUSDT=$FUSDT" >> deployed.stg.env

FUSDC=`npx oz create -n $NETWORK FToken --init initialize --args 1e6,$BANK_CONTROLLER,$IRM,$USDC,$BANK,1e18,\"ForTube\ USDC\",\"fUSDC\",18`
print_progress "FUSDC = $FUSDC"
echo "FUSDC=$FUSDC" >> deployed.stg.env

FBUSD=`npx oz create -n $NETWORK FToken --init initialize --args 1e18,$BANK_CONTROLLER,$IRM,$BUSD,$BANK,1e18,\"ForTube\ BUSD\",\"fBUSD\",18`
print_progress "FBUSD = $FBUSD"
echo "FBUSD=$FBUSD" >> deployed.stg.env

FHUSD=`npx oz create -n $NETWORK FToken --init initialize --args 1e8,$BANK_CONTROLLER,$IRM,$HUSD,$BANK,1e18,\"ForTube\ HUSD\",\"fHUSD\",18`
print_progress "FHUSD = $FHUSD"
echo "FHUSD=$FHUSD" >> deployed.stg.env

FDAI=`npx oz create -n $NETWORK FToken --init initialize --args 1e18,$BANK_CONTROLLER,$IRM,$DAI,$BANK,1e18,\"ForTube\ DAI\",\"fDAI\",18`
print_progress "FDAI = $FDAI"
echo "FDAI=$FDAI" >> deployed.stg.env

FFOR=`npx oz create -n $NETWORK FToken --init initialize --args 1e18,$BANK_CONTROLLER,$IRM,$FOR,$BANK,1e18,\"ForTube\ FOR\",\"fFOR\",18`
print_progress "FFOR = $FFOR"
echo "FFOR=$FFOR" >> deployed.stg.env

FBNB=`npx oz create -n $NETWORK FToken --init initialize --args 1e18,$BANK_CONTROLLER,$IRM,$BNB,$BANK,1e18,\"ForTube\ BNB\",\"fBNB\",18`
print_progress "FBNB = $FBNB"
echo "FBNB=$FBNB" >> deployed.stg.env

FHT=`npx oz create -n $NETWORK FToken --init initialize --args 1e18,$BANK_CONTROLLER,$IRM,$HT,$BANK,1e18,\"ForTube\ HT\",\"fHT\",18`
print_progress "FHT = $FHT"
echo "FHT=$FHT" >> deployed.stg.env

FOKB=`npx oz create -n $NETWORK FToken --init initialize --args 1e18,$BANK_CONTROLLER,$IRM,$OKB,$BANK,1e18,\"ForTube\ OKB\",\"fOKB\",18`
print_progress "FOKB = $FOKB"
echo "FOKB=$FOKB" >> deployed.stg.env

# FYUSD=`npx oz create -n $NETWORK FToken --init initialize --args 1e18,$BANK_CONTROLLER,$IRM,$YUSD,$BANK,1e18,\"ForTube\ yUSD\",\"fyUSD\",18`
# print_progress "FYUSD = $FYUSD"
# echo "FYUSD=$FYUSD" >> deployed.stg.env

# FYWETH=`npx oz create -n $NETWORK FToken --init initialize --args 1e18,$BANK_CONTROLLER,$IRM,$YWETH,$BANK,1e18,\"ForTube\ yWETH\",\"fyWETH\",18`
# print_progress "FYWETH = $FYWETH"
# echo "FYWETH=$FYWETH" >> deployed.stg.env

# FPAX=`npx oz create -n $NETWORK FToken --init initialize --args 1e18,$BANK_CONTROLLER,$IRM,$PAX,$BANK,1e18,\"ForTube\ PAX\",\"fPAX\",18`
# print_progress "FPAX = $FPAX"
# echo "FPAX=$FPAX" >> deployed.stg.env

# FTUSD=`npx oz create -n $NETWORK FToken --init initialize --args 1e18,$BANK_CONTROLLER,$IRM,$TUSD,$BANK,1e18,\"ForTube\ TUSD\",\"fTUSD\",18`
# print_progress "FTUSD = $FTUSD"
# echo "FTUSD=$FTUSD" >> deployed.stg.env

REWARD_POOL=`npx oz create -n $NETWORK RewardPool --init initialize --args $FOR,$BANK_CONTROLLER`
print_progress "REWARD_POOL = $REWARD_POOL"
echo "REWARD_POOL=$REWARD_POOL" >> deployed.stg.env

npx oz send-tx --to $BANK_CONTROLLER --method setTheForceToken -n $NETWORK --args $FOR
npx oz send-tx --to $BANK_CONTROLLER --method setBankEntryAddress -n $NETWORK --args $BANK
npx oz send-tx --to $BANK_CONTROLLER --method setOracle -n $NETWORK --args $PRICE_ORACLES
npx oz send-tx --to $BANK_CONTROLLER --method setRewardPool -n $NETWORK --args $REWARD_POOL
npx oz send-tx --to $BANK_CONTROLLER --method setRewardFactorByType -n $NETWORK --args 6,0
npx oz send-tx --to $BANK_CONTROLLER --method setCloseFactor -n $NETWORK --args 0.9e18

npx oz send-tx --to $PRICE_ORACLES --method setOracle -n $NETWORK --args $BOND_ORACLE
npx oz send-tx --to $PRICE_ORACLES --method setEthToUsdPrice -n $NETWORK --args $CHAIN_LINK_ORACLE

# fETH
npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FETH,0.75e18,1.1e18
# fHBTC
npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FHBTC,0.75e18,1.1e18
# fWBTC
npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FWBTC,0.75e18,1.1e18
# fUSDT
npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FUSDT,0.9e18,1.05e18
# fUSDC
npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FUSDC,0.9e18,1.05e18
# fBUSD
npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FBUSD,0.9e18,1.05e18
# fHUSD
npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FHUSD,0.9e18,1.05e18
# fDAI
npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FDAI,0.9e18,1.05e18
# fFOR
npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FFOR,0.4e18,1.15e18
# fBNB
npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FBNB,0.4e18,1.15e18

# fHT
npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FHT,0.4e18,1.15e18

# fOKB
npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FOKB,0.4e18,1.15e18

# # fYUSD
# npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FYUSD,0.9e18,1.05e18

# # fYWETH
# npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FYWETH,0.75e18,1.1e18

# # fPAX
# npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FPAX,0.9e18,1.05e18

# # fTUSD
# npx oz send-tx --to $BANK_CONTROLLER --method _supportMarket -n $NETWORK --args $FTUSD,0.9e18,1.05e18


npx oz send-tx --to $FETH --method _setReserveFactorFresh -n $NETWORK --args 0.2e18
npx oz send-tx --to $FHBTC --method _setReserveFactorFresh -n $NETWORK --args 0.2e18
npx oz send-tx --to $FUSDT --method _setReserveFactorFresh -n $NETWORK --args 0.2e18
npx oz send-tx --to $FUSDC --method _setReserveFactorFresh -n $NETWORK --args 0.2e18
npx oz send-tx --to $FBUSD --method _setReserveFactorFresh -n $NETWORK --args 0.2e18
npx oz send-tx --to $FHUSD --method _setReserveFactorFresh -n $NETWORK --args 0.2e18
npx oz send-tx --to $FDAI --method _setReserveFactorFresh -n $NETWORK --args 0.2e18
npx oz send-tx --to $FFOR --method _setReserveFactorFresh -n $NETWORK --args 0.2e18
npx oz send-tx --to $FBNB --method _setReserveFactorFresh -n $NETWORK --args 0.2e18
npx oz send-tx --to $FHT --method _setReserveFactorFresh -n $NETWORK --args 0.2e18
npx oz send-tx --to $FOKB --method _setReserveFactorFresh -n $NETWORK --args 0.2e18
#npx oz send-tx --to $FYUSD --method _setReserveFactorFresh -n $NETWORK --args 0.2e18
# npx oz send-tx --to $FYWETH --method _setReserveFactorFresh -n $NETWORK --args 0.2e18
#npx oz send-tx --to $FPAX --method _setReserveFactorFresh -n $NETWORK --args 0.2e18
#npx oz send-tx --to $FTUSD --method _setReserveFactorFresh -n $NETWORK --args 0.2e18

END=`date +%s`

print_success "\nDone. Runtime: $((END-START)) seconds."

exit 1
