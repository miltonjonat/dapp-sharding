import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";
import path from "path";

const ppath = (packageName: string, pathname: string) => {
  return path.join(
    path.dirname(require.resolve(`${packageName}/package.json`)),
    pathname
  );
};

const config: HardhatUserConfig = {
  solidity: "0.8.18",

  external: {
    contracts: [
      {
        artifacts: ppath("@cartesi/util", "/export/artifacts"),
        deploy: ppath("@cartesi/util", "/dist/deploy"),
      },
      {
        artifacts: ppath("@cartesi/rollups", "/export/artifacts"),
        deploy: ppath("@cartesi/rollups", "/dist/deploy"),
      },
    ],
    deployments: {
      localhost: ["deployments/localhost"],
      sepolia: [
        ppath("@cartesi/util", "/deployments/sepolia"),
        ppath("@cartesi/rollups", "/deployments/sepolia"),
      ],
    },
  },

  namedAccounts: {
    deployer: {
        default: 0,
    },
  },
};

export default config;
