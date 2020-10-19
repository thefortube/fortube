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
