# My Shopping Store

A decentralized transparent online shopping store dApp. User can place orders with their crypto wallet and can also cancel it before dispatch.

## Installation :

```shell
git clone git@github.com:nishajakhar/my-shopping-store.git
cd my-shopping-store
npm install
```


## To deploy the store contract

```shell
cp .env-example .env
// Update the Alchemy Key and Private key of your wallet account into the .env file
npx hardhat run scripts/deploy.js --network goerli
```
