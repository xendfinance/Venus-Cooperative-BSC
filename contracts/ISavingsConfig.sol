pragma solidity ^0.6.6;
import './ISavingsConfigSchema.sol';





interface  ISavingsConfig is ISavingsConfigSchema {
   
    function getRuleSet(string calldata ruleKey) external returns (uint ,uint , uint ,  bool ,RuleDefinition );
    function getRuleManager(string calldata ruleKey) external returns (address);
    function changeRuleCreator(string calldata ruleKey, address newRuleManager) external;
    function createRule(string calldata ruleKey, uint minimum, uint maximum, uint exact, RuleDefinition ruleDefinition) external;
    function modifyRule(string calldata ruleKey, uint minimum, uint maximum, uint exact,  RuleDefinition  ruleDefinition ) external;
    function disableRule(string calldata ruleKey) external;
    function enableRule(string calldata ruleKey)  external;
    
   
    
}