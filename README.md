## ForTube 2.0

### 1 Install the dependencies.

> npm install

### 2 Compile the contracts.

> npx oz compile --solc-version=0.6.4 --optimizer on

### 3 Deploy the contracts 

#### using the interactive command. (Recommended)

> npx oz deploy

#### using the non-interactive Javscript script. (Not Recommended)

According to the [doc](https://docs.openzeppelin.com/learn/upgrading-smart-contracts#upgrading-contracts-in-js), since the upgrade library is a semi-product, using the non-interactive Javscript script is not recommended.

> node src/deploy.js

### 4 Initial the contracts.

> node src/initial.js

### 5 Test the contracts.

> npm test (without compiling)

or 

> oz compile && mocha --exit --recursive test

or specify the test file

> npx mocha --exit test/Exponential.test.js

### 6 Upgrade the contracts.

#### using the interactive command. (Recommended)

> npx oz upgrade

#### using the non-interactive Javscript script. (Nope)

According to this [post](https://forum.openzeppelin.com/t/how-to-upgrade-contracts-programmatically/3156/8), there seems no better way to do this than using CLI.

## ETH contracts:

### ETH Innovation Market
BANK_CONTROLLER:
- https://etherscan.io/address/0x936E6490eD786FD0e0f0C1b1e4E1540b9D41F9eF#code

BANK:
- https://etherscan.io/address/0xdE7B3b2Fe0E7b4925107615A5b199a4EB40D9ca9#code

FETH:
- https://etherscan.io/address/0x5993233d88B4424D9c12e468A39736D5948c2835#code

FHBTC:
- https://etherscan.io/address/0x3CE92b88DEAec1037335E614Eb6409C95edcAC76#code

FWBTC:
- https://etherscan.io/address/0x93B9B852FcD2f964Faa7E50EC1374e016260718c#code

FUSDT:
- https://etherscan.io/address/0x51da0A7340874674C488b67200D007E422667650#code

FUSDC:
- https://etherscan.io/address/0xfDD543Ed2701dEB2a172Df4876E60918E28Ba217#code

FBUSD:
- https://etherscan.io/address/0x556be90ea81e8abceEc2737cf6AE0a6cfEe58b40#code

FHUSD:
- https://etherscan.io/address/0x52d61a0AA88170b6EbDEA25Be1561E5665e6481B#code

FDAI:
- https://etherscan.io/address/0xfF5cDA31926CA2Ed79533D6B95Fc6ADbDE0f1015#code

FFOR:
- https://etherscan.io/address/0x84ff569ee2E8b9A2C22E79af431fD248fb41D87b#code

FBNB:
- https://etherscan.io/address/0x92563b3b8c92B22e37aC956a2B19c40988D25933#code

FHT:
- https://etherscan.io/address/0x39527B067B04D43c627FB741848ef2c3f8ead3FE#code

FOKB:
- https://etherscan.io/address/0x4316AAa55ab3BD3a7ee3fbC83580521801210225#code

FYUSD:
- https://etherscan.io/address/0x66142B3c234C054bA91374732C10cEA0f72390fE#code

FYWETH:
- https://etherscan.io/address/0xd136b32330E539aa9411c4e8968eB26b35c5917B#code

FQC:
- https://etherscan.io/address/0x161190d29cC015EaEFD6c4ad0AA7519B6b75b9c0#code

FYFII:
- https://etherscan.io/address/0x4Ffc92ddD9439c93fc79dD5560e06026A445037D#code

FNEST:
- https://etherscan.io/address/0xbd3df917A7E69fBa3e1d912577Be7eCC01bE1d12#code

FARPA:
- https://etherscan.io/address/0x0486B8d96789C6938361Ab776D6b27b6FC03C471#code

FYFI:
- https://etherscan.io/address/0x8a06bbA4219C3f1Ca705318f5848E62f3beF33d0#code

FMKR:
- https://etherscan.io/address/0x9FC5d71FC9b14630a2f198F188450D26Fa5788f7#code

FLINK:
- https://etherscan.io/address/0x29B22BeFe0F5362986152a5430d03B446b8e27fB#code

FUNI:
- https://etherscan.io/address/0xDb694CB2B58F66C5E79fF272dF37ECb46Dc31ADD#code

FLRC:
- https://etherscan.io/address/0x6c2e2cEc8De4A6a071065D4BD5c496636570fDC2#code

FLEND:
- https://etherscan.io/address/0x45b4E177B17e2d50dB6D547015A6f9723FF9c1a0#code

FSNX:
- https://etherscan.io/address/0x8B2ef6d7d4Cc334D003398007722FdF8ca3f5E55#code

FHBCH:
- https://etherscan.io/address/0xA3423eb2426F9f7eA3224D7979125E4FD103CDAc#code

FHDOT:
- https://etherscan.io/address/0xb5c6edbA1808102E9fcA4cBDa33Af861a4e812C8#code

FHFIL:
- https://etherscan.io/address/0x9B0a69FD9858f294029cb76545106b1BD42e0eDA#code

FAAVE:
- https://etherscan.io/address/0x820FaBC044B198829cb11fc53B4E4048007fc415#code

FQUSD:
- https://etherscan.io/address/0xF0027DcAfC4eF004Dfdb2871B310d682148ed8c3#code

FBINANCE_BTC:
- https://etherscan.io/address/0xE61407c38BfC019bfa6751107052021B0084783A#code

FBINANCE_DOT:
- https://etherscan.io/address/0x939B9c50Ec4276F096C494c95CF363983Dc10739#code

FOBTC:
- https://etherscan.io/address/0x10E438782D0eACCECbae5FcEeAB5401a6816297e#code


### ETH Main Market

BANK_CONTROLLER_V3_STABLE:
- https://etherscan.io/address/0xb2835E469133D3B562065CC5ba49779162F094C5#code

BANK_V3_STABLE:
- https://etherscan.io/address/0x2378a77296904C767e6570365ceB5819d34D43C3#code

SFETH:
- https://etherscan.io/address/0x67d29c41289940694260088A78a71e37FBD2A821#code

SFWBTC:
- https://etherscan.io/address/0x86598C780AaAB7f4c4b09879dD4a42aA0a420fD2#code

SFHBTC:
- https://etherscan.io/address/0xd623dd315361818cbbd0c0e10130931155DA31eD#code

SFUSDT:
- https://etherscan.io/address/0x37b77bE1379E77c485EC4721feeDe5190e045Abc#code

SFUSDC:
- https://etherscan.io/address/0x4ba004c4353314dfE9E516b5C159880699F50d85#code

SFDAI:
- https://etherscan.io/address/0xB4bA7A4F35129A6009006D3da68bbbb19465Ea9a#code

## BSC contracts:
### BSC Innovation Market
BANK_CONTROLLER:
- https://bscscan.com/address/0xc78248D676DeBB4597e88071D3d889eCA70E5469#code

BANK:
- https://bscscan.com/address/0x0cEA0832e9cdBb5D476040D58Ea07ecfbeBB7672#code

FUSDT:
- https://bscscan.com/address/0xBf9213D046C2c1e6775dA2363fC47F10C4471255#code

FBUSD:
- https://bscscan.com/address/0x57160962Dc107C8FBC2A619aCA43F79Fd03E7556#code

FDAI:
- https://bscscan.com/address/0x312e1635BCB5D1410F1BC52640592EA4F63820ef#code

FETH:
- https://bscscan.com/address/0xE2272A850188B43E94eD6DF5b75f1a2FDcd5aC26#code

FBNB:
- https://bscscan.com/address/0xf330b39f74e7f71ab9604A5307690872b8125aC8#code

FBTCB:
- https://bscscan.com/address/0xb5C15fD55C73d9BeeC046CB4DAce1e7975DcBBBc#code

FBCH:
- https://bscscan.com/address/0x33d6D5F813BF78163901b1e72Fb1fEB90E72fD72#code

FLTC:
- https://bscscan.com/address/0x3Ccc8A3D59F8277bF0d598EA3199418c55cD6CA9#code

FXRP:
- https://bscscan.com/address/0x5Aa9FD16FF5D336BeFC87ED0c7B4B5194530AA9B#code

FDOT:
- https://bscscan.com/address/0x534CD786C2907ABb600feC375D4B513700e592D3#code

FLINK:
- https://bscscan.com/address/0xF8C5965BfBAE9c429F91BA357d930Ed78ffd4cF9#code

FONT:
- https://bscscan.com/address/0x0C2F5921681a7dd956e223fae5DC23502BcB43cD#code

FXTZ:
- https://bscscan.com/address/0x9435e4B80FaA75E2ec770d134dCeA1B590A4E6FB#code

FEOS:
- https://bscscan.com/address/0x8CCDba35C3E3c6ce513B4cB058c1cF2f9bEfc9B3#code

FFOR:
- https://bscscan.com/address/0x53345F3B9FCb873783FfA5C8F043233AfD4991a6#code

FYFII:
- https://bscscan.com/address/0x2c2ca6abAcb43f38d86253d8d762687DB43Dc0d0#code

FZEC:
- https://bscscan.com/address/0xcdBcD1c5237DE8954b5E76149Bad0aAFc114df99#code

FCREAM:
- https://bscscan.com/address/0x25a7c3A4f1ceffB5C8907Ce28719FC5f8f2962B6#code

FBAND:
- https://bscscan.com/address/0x77ccecaf88df25e29a2be941abdcb8f98a33eae3#code

FCAN:
- https://bscscan.com/address/0x66D6cb443c7E1291AbA34A5c0cF562894092c4ae#code

FADA:
- https://bscscan.com/address/0xe4F621719D6b9f1C392DA83e8d766D55b5663805#code

FATOM:
- https://bscscan.com/address/0x5f6ffEE82666Db203d89fcf5ea730113455503Cb#code

FFIL:
- https://bscscan.com/address/0xEe65F5eD0767D935318CBA04D68e7931Ad0B508b#code

FQUSD:
- https://bscscan.com/address/0x13902753864b13e486E573661Af919A7AD080F19#code

FBETH:
- https://bscscan.com/address/0xf1f3147cebc1D74C88dFA56941E802ADcF788E03#code

FCAKE:
- https://bscscan.com/address/0xa339C0ae7e47596017CCe2ac1459349A4f0aeb6C#code


### BSC Main Market
BANK_CONTROLLER_V3_STABLE:
- https://bscscan.com/address/0x89Aa35B14F500C40D68cC6F2B7E55Ff03017aa70#code

BANK_V3_STABLE:
- https://bscscan.com/address/0x2f4F03eA63B0dB1dcEED3c1C84295bd62Bd5Df5A#code

SFBTCB:
- https://bscscan.com/address/0xeD3BcEF2573860216218491aA3f0F874724535fb#code

SFETH:
- https://bscscan.com/address/0xA28F1b342F2827300cdCe95e64118007C2e553f0#code

SFUSDT:
- https://bscscan.com/address/0x9Df173035175a7146aDc064fFA59971E72a1B438#code

SFUSDC:
- https://bscscan.com/address/0xB5A802761379359DE4B91e4bd554d64c85739ab4#code

SFBUSD:
- https://bscscan.com/address/0x7a3E4797149cf8A6909469025533cf6419BC91b0#code

SFDAI:
- https://bscscan.com/address/0x392D2b8a840BbaC3EfaB3883B25A100f6E7EA170#code

