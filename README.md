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

https://etherscan.io/address/0x936E6490eD786FD0e0f0C1b1e4E1540b9D41F9eF#code
https://etherscan.io/address/0xC05E28cb46605778A247A6e25aB016897527979d#code
https://etherscan.io/address/0x341661a71bbCfEA48CdcF0A104aF3e708aABeBf9#code
https://etherscan.io/address/0x5E7315fF9b08F2a2765Fac3039C5b01350E2d298#code
https://etherscan.io/address/0xf8345037Da48e90A68A9590C4bBAad6fbbd62661#code
https://etherscan.io/address/0xdE7B3b2Fe0E7b4925107615A5b199a4EB40D9ca9#code
https://etherscan.io/address/0x775f9099e24CD67f75232245719f363c0243783F#code
https://etherscan.io/address/0x322401fff76dda9cea5595aaa90d062798907bde#code
https://etherscan.io/address/0x84ff569ee2E8b9A2C22E79af431fD248fb41D87b#code

## BSC contracts:

https://bscscan.com/address/0xc78248D676DeBB4597e88071D3d889eCA70E5469#code
https://bscscan.com/address/0x19d76F29ca659bcFe95056A4b03885CC1439B257#code
https://bscscan.com/address/0xb932d9f1641C0f8181117944FB8Ac3e41c837fdC#code
https://bscscan.com/address/0x6CC6F9BF4C235C8Aa4F72EC3EdB61819DE914f4E#code
https://bscscan.com/address/0xdC30dA5Aaa5F48c71156353235Aa4D730263dD31#code
https://bscscan.com/address/0x0cEA0832e9cdBb5D476040D58Ea07ecfbeBB7672#code
https://bscscan.com/address/0xD57f6b7A1027C2dD3E628653784455172f765671#code
https://bscscan.com/address/0x2197bcefbf965d9ae3b081a63a22e0dcf3bcc6e6#code
https://bscscan.com/address/0x53345F3B9FCb873783FfA5C8F043233AfD4991a6#code
