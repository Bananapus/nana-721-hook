pragma solidity 0.8.6;

import '../interfaces/IJBTieredLimitedNFTRewardDataSourceProjectDeployer.sol';
import 'forge-std/Script.sol';

// Change values in setUp() and createData()
contract RinkebyLaunchProjectFor is Script {
  IJBTieredLimitedNFTRewardDataSourceProjectDeployer deployer = IJBTieredLimitedNFTRewardDataSourceProjectDeployer(0xaB28b6ee8D23EB47F6FC2d55ec023572E15eB6e6);
  IJBController jbController;
  IJBDirectory jbDirectory;
  IJBPaymentTerminal[] _terminals;
  JBFundAccessConstraints[] _fundAccessConstraints;

  string name;
  string symbol;
  string baseUri;
  string contractUri;

  address _projectOwner;

  function setUp() public {
    _projectOwner = msg.sender; // Change me
    jbController = deployer.controller();
    jbDirectory = jbController.directory();
    name = "My NFT Collection"; // Change me
    symbol = "CANSMASHING";
    baseUri = "ipfs://baseUri";
    contractUri = "ipfs://royaltiezz";
  }

  function run() external {
    (
      JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    ) = createData();

    vm.startBroadcast();

    uint256 projectId = deployer.launchProjectFor(
      _projectOwner,
      NFTRewardDeployerData,
      launchProjectData
    );

    console.log(projectId);
  }

  function createData()
    internal
    returns (
      JBDeployTieredNFTRewardDataSourceData memory NFTRewardDeployerData,
      JBLaunchProjectData memory launchProjectData
    )
  {

    // Project configuration
    JBProjectMetadata memory _projectMetadata = JBProjectMetadata({content: 'myIPFSHash', domain: 1});
    JBFundingCycleData memory _data = JBFundingCycleData({
        duration: 14,
        weight: 1000 * 10**18,
        discountRate: 450000000,
        ballot: IJBFundingCycleBallot(address(0))
    });

    JBFundingCycleMetadata memory _metadata = JBFundingCycleMetadata({
        global: JBGlobalFundingCycleMetadata({allowSetTerminals: false, allowSetController: false}),
        reservedRate: 5000,
        redemptionRate: 5000, //50%
        ballotRedemptionRate: 5000,
        pausePay: false,
        pauseDistributions: false,
        pauseRedeem: false,
        pauseBurn: false,
        allowMinting: true,
        allowChangeToken: true,
        allowTerminalMigration: false,
        allowControllerMigration: false,
        holdFees: false,
        useTotalOverflowForRedemptions: false,
        useDataSourceForPay: true,
        useDataSourceForRedeem: true,
        dataSource: address(0) // Will get overriden during deployment
    });

    JBSplit[] memory _splits = new JBSplit[](1);
    _splits[0] = JBSplit({
      preferClaimed: false,
      preferAddToBalance: false,
      percent: 1000000000, 
      projectId: 0,
      beneficiary: payable(_projectOwner),
      lockedUntil: 0,
      allocator: IJBSplitAllocator(address(0))
    });

    JBGroupedSplits[] memory _groupedSplits = new JBGroupedSplits[](1);
    _groupedSplits[0] = JBGroupedSplits({group: 1, splits: _splits});

    _terminals.push(IJBPaymentTerminal(0x53A92F883903a4C80bC47Cfed788c1a477dadc5c));
    
    _fundAccessConstraints.push(JBFundAccessConstraints({
        terminal: _terminals[0],
        token: address(0x000000000000000000000000000000000000EEEe), // ETH
        distributionLimit: 100 ether,
        overflowAllowance: 0,
        distributionLimitCurrency: 1, // ETH
        overflowAllowanceCurrency: 1
      })
    );

    // NFT Reward parameters
    JBNFTRewardTier[] memory tiers = new JBNFTRewardTier[](10);

    for (uint256 i; i < 10; i++) {
      tiers[i] = JBNFTRewardTier({
        contributionFloor: uint128((i + 1) * 10),
        idCeiling: uint48((i + 1) * 10),
        remainingAllowance: uint40(10),
        initialAllowance: uint40(10)
      });
    }

    NFTRewardDeployerData = JBDeployTieredNFTRewardDataSourceData({
      directory: jbDirectory,
      name: name,
      symbol: symbol,
      tokenUriResolver: IJBTokenUriResolver(address(0)),
      baseUri: baseUri,
      contractUri: contractUri,
      owner: _projectOwner,
      contributionToken: address(0x000000000000000000000000000000000000EEEe), // ETH
      tiers: tiers
    });

    launchProjectData = JBLaunchProjectData({
      projectMetadata: _projectMetadata,
      data: _data,
      metadata: _metadata,
      mustStartAtOrAfter: 0,
      groupedSplits: _groupedSplits,
      fundAccessConstraints: _fundAccessConstraints,
      terminals: _terminals,
      memo: ''
    });
  }
}