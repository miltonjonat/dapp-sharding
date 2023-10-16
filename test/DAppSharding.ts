import { deployments, ethers, } from "hardhat";
import { CartesiDApp__factory, DAppSharding__factory } from "../typechain-types";
import { AuthorityFactory__factory, CartesiDAppFactory__factory, InputBox__factory } from "@cartesi/rollups";
import { expect } from "chai";

describe("DAppSharding", function () {

  const MAIN_TEMPLATE_HASH = "0xb091eff80733ff3a75b190107fce6fd93cd73b245e7239a782ecd65ff3932fe6";
  const VERIFIER_TEMPLATE_HASH = "0x2e57c8f996e73d50473276bae49e7ad97b84ea5ae34af1bc2ed0e71908dd9461";
  const SHARD_ID = "0x0000000000000000000000000000000000000000000000000000000000000001";

  it("Shard creation", async function () {
    // run deployments fixture and collect relevant deployed contracts info
    await deployments.fixture();
    const { AuthorityFactory, InputBox, CartesiDAppFactory, DAppSharding } = await deployments.all();

    // build typed contract objects
    const [signer] = await ethers.getSigners();
    const authFactory = AuthorityFactory__factory.connect(AuthorityFactory.address, signer);
    const inputBox = InputBox__factory.connect(InputBox.address, signer);
    const dappFactory = CartesiDAppFactory__factory.connect(CartesiDAppFactory.address, signer);
    const dappSharding = DAppSharding__factory.connect(DAppSharding.address, signer);

    // deploy authority
    let tx = await authFactory["newAuthority(address,bytes32)"](signer.address, ethers.constants.HashZero);
    let events = (await tx.wait()).events;
    const authAddress = events?.find(e => e.event == "AuthorityCreated")?.args?.[1];
    
    // deploy "Main DApp"
    tx = await dappFactory["newApplication(address,address,bytes32,bytes32)"](authAddress, signer.address, MAIN_TEMPLATE_HASH, ethers.constants.HashZero);
    events = (await tx.wait()).events;
    const mainDAppAddress = events?.find(e => e.event == "ApplicationCreated")?.args?.[3];

    // calculated a shard's expected address
    const expectedAddress = await dappSharding.calculateShardAddress(mainDAppAddress, VERIFIER_TEMPLATE_HASH, SHARD_ID);
    
    // deploy shard
    tx = await dappSharding.createShard(mainDAppAddress, VERIFIER_TEMPLATE_HASH, SHARD_ID);
    events = (await tx.wait()).events;

    // check shard address
    const shardAddress = events?.map(event => {
      try {
        return dappFactory.interface.parseLog(event);
      } catch (error) {}
    }).find(parsedEvent => parsedEvent?.name == "ApplicationCreated")?.args?.[3];
    expect(expectedAddress.toLowerCase()).to.eql(shardAddress.toLowerCase());

    // collect generated inputs
    const inputs = events?.map(e => {
      try {
        return inputBox.interface.parseLog(e);
      } catch (error) {}
    }).filter(e => e?.name == "InputAdded").map(e => e?.args[3]);
    expect(inputs?.length).to.eql(2);

    // check 1st input: inform MainDApp about new shard
    const inputMain = inputs?.[0];
    expect(inputMain.length).to.eql(210); // 2 addresses + 2 bytes32 in hex
    expect(inputMain.slice(2,42).toLowerCase()).to.eql(shardAddress.slice(2).toLowerCase());
    expect(inputMain.slice(42,82).toLowerCase()).to.eql(signer.address.slice(2).toLowerCase());
    expect(inputMain.slice(82,146).toLowerCase()).to.eql(VERIFIER_TEMPLATE_HASH.slice(2).toLowerCase());
    expect(inputMain.slice(146).toLowerCase()).to.eql(SHARD_ID.slice(2).toLowerCase());

    // check 2nd input: inform shard about MainDApp's address
    const inputShard = inputs?.[1];
    expect(inputShard.toLowerCase()).to.eql(mainDAppAddress.toLowerCase());
  });
});
