use starknet::ContractAddress;

#[starknet::interface]
trait IPlatformGovernance<TContractState> {
    // Core governance functions
    fn create_proposal(
        ref self: TContractState,
        title: felt252,
        description: ByteArray,
        proposal_type: u8,
        voting_duration: u64,
        execution_delay: u64
    ) -> u256;
    fn vote_on_proposal(ref self: TContractState, proposal_id: u256, vote: bool);
    fn execute_proposal(ref self: TContractState, proposal_id: u256);
    fn get_proposal_status(self: @TContractState, proposal_id: u256) -> ProposalStatus;
    fn delegate_voting_power(ref self: TContractState, delegate: ContractAddress);
    fn revoke_delegation(ref self: TContractState);
    
    // Emergency governance functions
    fn create_emergency_proposal(
        ref self: TContractState,
        title: felt252,
        description: ByteArray,
        emergency_type: u8
    ) -> u256;
    fn emergency_execute(ref self: TContractState, proposal_id: u256);
    
    // Platform parameter management
    fn update_platform_parameter(
        ref self: TContractState,
        parameter_type: u8,
        new_value: u256
    );
    fn get_platform_parameter(self: @TContractState, parameter_type: u8) -> u256;
    
    // Governance configuration
    fn update_governance_config(
        ref self: TContractState,
        min_voting_power: u256,
        min_proposal_duration: u64,
        max_proposal_duration: u64,
        emergency_voting_duration: u64
    );
    
    // Query functions
    fn get_proposal_details(self: @TContractState, proposal_id: u256) -> EnhancedProposal;
    fn get_proposal_count(self: @TContractState) -> u256;
    fn get_voting_power(self: @TContractState, user: ContractAddress) -> u256;
    fn get_delegated_power(self: @TContractState, delegate: ContractAddress) -> u256;
}

#[derive(Drop, Serde, starknet::Store)]
struct EnhancedProposal {
    id: u256,
    title: felt252,
    description: ByteArray,
    proposer: ContractAddress,
    votes_for: u256,
    votes_against: u256,
    voting_deadline: u64,
    execution_deadline: u64,
    executed: bool,
    proposal_type: u8, // 0: Platform Update, 1: Fee Change, 2: Policy Change, 3: Emergency, 4: Parameter, 5: Governance
    created_at: u64,
    is_emergency: bool,
    emergency_type: u8, // 0: Security, 1: Critical Bug, 2: Economic Emergency
    time_lock_delay: u64,
    execution_timestamp: u64,
}

#[derive(Drop, Serde, starknet::Store)]
struct ProposalStatus {
    is_active: bool,
    is_approved: bool,
    is_executable: bool,
    is_emergency: bool,
    time_until_execution: u64,
    total_votes: u256,
    quorum_met: bool,
}

#[derive(Drop, Serde, starknet::Store)]
struct PlatformParameters {
    fee_distribution_treasury: u8,
    fee_distribution_providers: u8,
    fee_distribution_governance: u8,
    fee_distribution_development: u8,
    min_voting_power: u256,
    min_proposal_duration: u64,
    max_proposal_duration: u64,
    emergency_voting_duration: u64,
    time_lock_delay_normal: u64,
    time_lock_delay_emergency: u64,
    quorum_percentage: u8,
    emergency_quorum_percentage: u8,
    last_updated: u64,
}

#[derive(Drop, Serde, starknet::Store)]
struct EmergencyCouncil {
    members: Array<ContractAddress>,
    required_signatures: u8,
    is_active: bool,
}

#[starknet::contract]
mod PlatformGovernance {
    use super::{
        IPlatformGovernance, EnhancedProposal, ProposalStatus, PlatformParameters, EmergencyCouncil
    };
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };

    #[storage]
    struct Storage {
        // Core governance storage
        proposals: Map<u256, EnhancedProposal>,
        proposal_count: u256,
        voter_has_voted: Map<(u256, ContractAddress), bool>,
        voter_voting_power: Map<(u256, ContractAddress), u256>,
        
        // Platform parameters
        platform_parameters: PlatformParameters,
        
        // Emergency governance
        emergency_council: EmergencyCouncil,
        emergency_proposals: Map<u256, bool>,
        
        // External contract addresses
        voting_power_contract: ContractAddress,
        fee_distribution_contract: ContractAddress,
        reputation_contract: ContractAddress,
        service_marketplace_contract: ContractAddress,
        
        // Governance state
        governance_paused: bool,
        emergency_mode: bool,
        
        // Delegation tracking
        delegations: Map<ContractAddress, ContractAddress>,
        delegated_power: Map<ContractAddress, u256>,
        
        // Time-lock tracking
        time_locked_proposals: Map<u256, u64>,
        executed_proposals: Map<u256, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ProposalCreated: ProposalCreated,
        VoteCast: VoteCast,
        ProposalExecuted: ProposalExecuted,
        EmergencyProposalCreated: EmergencyProposalCreated,
        EmergencyExecuted: EmergencyExecuted,
        PlatformParameterUpdated: PlatformParameterUpdated,
        GovernanceConfigUpdated: GovernanceConfigUpdated,
        EmergencyCouncilUpdated: EmergencyCouncilUpdated,
        DelegationUpdated: DelegationUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalCreated {
        #[key]
        proposal_id: u256,
        #[key]
        proposer: ContractAddress,
        title: felt252,
        proposal_type: u8,
        voting_deadline: u64,
        execution_deadline: u64,
        is_emergency: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct VoteCast {
        #[key]
        proposal_id: u256,
        #[key]
        voter: ContractAddress,
        vote: bool,
        voting_power: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalExecuted {
        #[key]
        proposal_id: u256,
        votes_for: u256,
        votes_against: u256,
        execution_timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct EmergencyProposalCreated {
        #[key]
        proposal_id: u256,
        #[key]
        proposer: ContractAddress,
        emergency_type: u8,
        title: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct EmergencyExecuted {
        #[key]
        proposal_id: u256,
        emergency_type: u8,
        execution_timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct PlatformParameterUpdated {
        parameter_type: u8,
        old_value: u256,
        new_value: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct GovernanceConfigUpdated {
        min_voting_power: u256,
        min_proposal_duration: u64,
        max_proposal_duration: u64,
        emergency_voting_duration: u64,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct EmergencyCouncilUpdated {
        member_count: u8,
        required_signatures: u8,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct DelegationUpdated {
        #[key]
        delegator: ContractAddress,
        #[key]
        delegate: ContractAddress,
        power: u256,
        action: felt252, // "delegate" or "revoke"
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        voting_power_contract: ContractAddress,
        fee_distribution_contract: ContractAddress,
        reputation_contract: ContractAddress,
        service_marketplace_contract: ContractAddress
    ) {
        self.voting_power_contract.write(voting_power_contract);
        self.fee_distribution_contract.write(fee_distribution_contract);
        self.reputation_contract.write(reputation_contract);
        self.service_marketplace_contract.write(service_marketplace_contract);
        
        // Initialize platform parameters
        let params = PlatformParameters {
            fee_distribution_treasury: 40,
            fee_distribution_providers: 35,
            fee_distribution_governance: 15,
            fee_distribution_development: 10,
            min_voting_power: 100,
            min_proposal_duration: 86400, // 1 day
            max_proposal_duration: 2592000, // 30 days
            emergency_voting_duration: 3600, // 1 hour
            time_lock_delay_normal: 172800, // 2 days
            time_lock_delay_emergency: 3600, // 1 hour
            quorum_percentage: 10, // 10% of total voting power
            emergency_quorum_percentage: 5, // 5% for emergency proposals
            last_updated: get_block_timestamp(),
        };
        self.platform_parameters.write(params);
        
        // Initialize emergency council
        let council = EmergencyCouncil {
            members: ArrayTrait::new(),
            required_signatures: 3,
            is_active: true,
        };
        self.emergency_council.write(council);
        
        self.proposal_count.write(0);
        self.governance_paused.write(false);
        self.emergency_mode.write(false);
    }

    #[abi(embed_v0)]
    impl PlatformGovernanceImpl of IPlatformGovernance<ContractState> {
        fn create_proposal(
            ref self: ContractState,
            title: felt252,
            description: ByteArray,
            proposal_type: u8,
            voting_duration: u64,
            execution_delay: u64
        ) -> u256 {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Check if governance is paused
            assert(!self.governance_paused.read(), 'Governance is paused');
            
            // Validate proposal type
            assert(proposal_type <= 5, 'Invalid proposal type');
            
            // Validate voting duration
            let params = self.platform_parameters.read();
            assert(
                voting_duration >= params.min_proposal_duration && 
                voting_duration <= params.max_proposal_duration, 
                'Invalid voting duration'
            );
            
            // Check minimum voting power for proposal creation
            let proposer_power = self._get_voting_power(caller);
            assert(proposer_power >= params.min_voting_power, 'Insufficient voting power to propose');
            
            let proposal_id = self.proposal_count.read() + 1;
            self.proposal_count.write(proposal_id);
            
            let voting_deadline = current_time + voting_duration;
            let execution_deadline = voting_deadline + execution_delay;
            
            let proposal = EnhancedProposal {
                id: proposal_id,
                title,
                description,
                proposer: caller,
                votes_for: 0,
                votes_against: 0,
                voting_deadline,
                execution_deadline,
                executed: false,
                proposal_type,
                created_at: current_time,
                is_emergency: false,
                emergency_type: 0,
                time_lock_delay: execution_delay,
                execution_timestamp: 0,
            };
            
            self.proposals.entry(proposal_id).write(proposal);
            
            self.emit(ProposalCreated {
                proposal_id,
                proposer: caller,
                title,
                proposal_type,
                voting_deadline,
                execution_deadline,
                is_emergency: false,
            });
            
            proposal_id
        }

        fn vote_on_proposal(ref self: ContractState, proposal_id: u256, vote: bool) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Check if governance is paused
            assert(!self.governance_paused.read(), 'Governance is paused');
            
            // Get proposal
            let mut proposal = self.proposals.entry(proposal_id).read();
            assert(proposal.id != 0, 'Proposal does not exist');
            
            // Check if voting period is still active
            assert(current_time <= proposal.voting_deadline, 'Voting period ended');
            
            // Check if user already voted
            assert(!self.voter_has_voted.entry((proposal_id, caller)).read(), 'Already voted');
            
            // Get voting power
            let voting_power = self._get_voting_power(caller);
            let params = self.platform_parameters.read();
            assert(voting_power >= params.min_voting_power, 'Insufficient voting power');
            
            // Record vote
            self.voter_has_voted.entry((proposal_id, caller)).write(true);
            self.voter_voting_power.entry((proposal_id, caller)).write(voting_power);
            
            // Update vote counts
            if vote {
                proposal.votes_for += voting_power;
            } else {
                proposal.votes_against += voting_power;
            }
            
            self.proposals.entry(proposal_id).write(proposal);
            
            self.emit(VoteCast {
                proposal_id,
                voter: caller,
                vote,
                voting_power,
            });
        }

        fn execute_proposal(ref self: ContractState, proposal_id: u256) {
            let current_time = get_block_timestamp();
            let mut proposal = self.proposals.entry(proposal_id).read();
            
            // Validate proposal exists and hasn't been executed
            assert(proposal.id != 0, 'Proposal does not exist');
            assert(!proposal.executed, 'Proposal already executed');
            assert(current_time >= proposal.execution_deadline, 'Time-lock period not ended');
            
            // Check if proposal passed
            let total_votes = proposal.votes_for + proposal.votes_against;
            assert(total_votes > 0, 'No votes cast');
            
            let params = self.platform_parameters.read();
            let quorum_required = self._calculate_quorum(proposal.is_emergency);
            assert(total_votes >= quorum_required, 'Quorum not met');
            assert(proposal.votes_for > proposal.votes_against, 'Proposal failed');
            
            // Mark as executed
            proposal.executed = true;
            proposal.execution_timestamp = current_time;
            self.proposals.entry(proposal_id).write(proposal);
            self.executed_proposals.entry(proposal_id).write(true);
            
            // Execute proposal logic
            self._execute_proposal_logic(proposal.proposal_type, proposal_id);
            
            self.emit(ProposalExecuted {
                proposal_id,
                votes_for: proposal.votes_for,
                votes_against: proposal.votes_against,
                execution_timestamp: current_time,
            });
        }

        fn get_proposal_status(self: @ContractState, proposal_id: u256) -> ProposalStatus {
            let proposal = self.proposals.entry(proposal_id).read();
            let current_time = get_block_timestamp();
            
            if proposal.id == 0 {
                return ProposalStatus {
                    is_active: false,
                    is_approved: false,
                    is_executable: false,
                    is_emergency: false,
                    time_until_execution: 0,
                    total_votes: 0,
                    quorum_met: false,
                };
            }
            
            let total_votes = proposal.votes_for + proposal.votes_against;
            let quorum_required = self._calculate_quorum(proposal.is_emergency);
            let quorum_met = total_votes >= quorum_required;
            let is_approved = proposal.votes_for > proposal.votes_against;
            let is_active = current_time <= proposal.voting_deadline;
            let is_executable = current_time >= proposal.execution_deadline && !proposal.executed && is_approved;
            let time_until_execution = if current_time < proposal.execution_deadline {
                proposal.execution_deadline - current_time
            } else {
                0
            };
            
            ProposalStatus {
                is_active,
                is_approved,
                is_executable,
                is_emergency: proposal.is_emergency,
                time_until_execution,
                total_votes,
                quorum_met,
            }
        }

        fn delegate_voting_power(ref self: ContractState, delegate: ContractAddress) {
            let caller = get_caller_address();
            assert(caller != delegate, 'Cannot delegate to self');
            
            let voting_power = self._get_voting_power(caller);
            assert(voting_power > 0, 'No voting power to delegate');
            
            // Remove from current delegate if exists
            let current_delegate = self.delegations.entry(caller).read();
            if current_delegate.is_non_zero() {
                let current_delegated = self.delegated_power.entry(current_delegate).read();
                self.delegated_power.entry(current_delegate).write(current_delegated - voting_power);
            }
            
            // Add to new delegate
            let delegated_power = self.delegated_power.entry(delegate).read();
            self.delegated_power.entry(delegate).write(delegated_power + voting_power);
            self.delegations.entry(caller).write(delegate);
            
            self.emit(DelegationUpdated {
                delegator: caller,
                delegate,
                power: voting_power,
                action: 'delegate',
            });
        }

        fn revoke_delegation(ref self: ContractState) {
            let caller = get_caller_address();
            let delegate = self.delegations.entry(caller).read();
            
            assert(delegate.is_non_zero(), 'No active delegation');
            
            let voting_power = self._get_voting_power(caller);
            let current_delegated = self.delegated_power.entry(delegate).read();
            self.delegated_power.entry(delegate).write(current_delegated - voting_power);
            
            // Clear delegation
            self.delegations.entry(caller).write(starknet::contract_address_const::<0>());
            
            self.emit(DelegationUpdated {
                delegator: caller,
                delegate,
                power: voting_power,
                action: 'revoke',
            });
        }

        fn create_emergency_proposal(
            ref self: ContractState,
            title: felt252,
            description: ByteArray,
            emergency_type: u8
        ) -> u256 {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Check if caller is emergency council member
            assert(self._is_emergency_council_member(caller), 'Not emergency council member');
            assert(emergency_type <= 2, 'Invalid emergency type');
            
            let proposal_id = self.proposal_count.read() + 1;
            self.proposal_count.write(proposal_id);
            
            let params = self.platform_parameters.read();
            let voting_deadline = current_time + params.emergency_voting_duration;
            let execution_deadline = voting_deadline + params.time_lock_delay_emergency;
            
            let proposal = EnhancedProposal {
                id: proposal_id,
                title,
                description,
                proposer: caller,
                votes_for: 0,
                votes_against: 0,
                voting_deadline,
                execution_deadline,
                executed: false,
                proposal_type: 3, // Emergency type
                created_at: current_time,
                is_emergency: true,
                emergency_type,
                time_lock_delay: params.time_lock_delay_emergency,
                execution_timestamp: 0,
            };
            
            self.proposals.entry(proposal_id).write(proposal);
            self.emergency_proposals.entry(proposal_id).write(true);
            
            self.emit(EmergencyProposalCreated {
                proposal_id,
                proposer: caller,
                emergency_type,
                title,
            });
            
            proposal_id
        }

        fn emergency_execute(ref self: ContractState, proposal_id: u256) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Check if caller is emergency council member
            assert(self._is_emergency_council_member(caller), 'Not emergency council member');
            
            let mut proposal = self.proposals.entry(proposal_id).read();
            assert(proposal.id != 0, 'Proposal does not exist');
            assert(proposal.is_emergency, 'Not an emergency proposal');
            assert(!proposal.executed, 'Proposal already executed');
            
            // For emergency proposals, can execute immediately after approval
            let total_votes = proposal.votes_for + proposal.votes_against;
            assert(total_votes > 0, 'No votes cast');
            
            let quorum_required = self._calculate_quorum(true);
            assert(total_votes >= quorum_required, 'Emergency quorum not met');
            assert(proposal.votes_for > proposal.votes_against, 'Emergency proposal failed');
            
            // Mark as executed
            proposal.executed = true;
            proposal.execution_timestamp = current_time;
            self.proposals.entry(proposal_id).write(proposal);
            self.executed_proposals.entry(proposal_id).write(true);
            
            // Execute emergency logic
            self._execute_emergency_logic(proposal.emergency_type, proposal_id);
            
            self.emit(EmergencyExecuted {
                proposal_id,
                emergency_type: proposal.emergency_type,
                execution_timestamp: current_time,
            });
        }

        fn update_platform_parameter(
            ref self: ContractState,
            parameter_type: u8,
            new_value: u256
        ) {
            let caller = get_caller_address();
            
            // Only emergency council or approved proposals can update parameters
            assert(
                self._is_emergency_council_member(caller) || 
                self._has_governance_permission(caller), 
                'No permission to update parameters'
            );
            
            let mut params = self.platform_parameters.read();
            let old_value = self._get_parameter_value(parameter_type, params);
            
            // Update parameter based on type
            self._update_parameter_by_type(parameter_type, new_value, ref params);
            params.last_updated = get_block_timestamp();
            
            self.platform_parameters.write(params);
            
            self.emit(PlatformParameterUpdated {
                parameter_type,
                old_value,
                new_value,
                timestamp: get_block_timestamp(),
            });
        }

        fn get_platform_parameter(self: @ContractState, parameter_type: u8) -> u256 {
            let params = self.platform_parameters.read();
            self._get_parameter_value(parameter_type, params)
        }

        fn update_governance_config(
            ref self: ContractState,
            min_voting_power: u256,
            min_proposal_duration: u64,
            max_proposal_duration: u64,
            emergency_voting_duration: u64
        ) {
            let caller = get_caller_address();
            assert(self._is_emergency_council_member(caller), 'Only emergency council can update config');
            
            let mut params = self.platform_parameters.read();
            params.min_voting_power = min_voting_power;
            params.min_proposal_duration = min_proposal_duration;
            params.max_proposal_duration = max_proposal_duration;
            params.emergency_voting_duration = emergency_voting_duration;
            params.last_updated = get_block_timestamp();
            
            self.platform_parameters.write(params);
            
            self.emit(GovernanceConfigUpdated {
                min_voting_power,
                min_proposal_duration,
                max_proposal_duration,
                emergency_voting_duration,
                timestamp: get_block_timestamp(),
            });
        }

        fn get_proposal_details(self: @ContractState, proposal_id: u256) -> EnhancedProposal {
            self.proposals.entry(proposal_id).read()
        }

        fn get_proposal_count(self: @ContractState) -> u256 {
            self.proposal_count.read()
        }

        fn get_voting_power(self: @ContractState, user: ContractAddress) -> u256 {
            self._get_voting_power(user)
        }

        fn get_delegated_power(self: @ContractState, delegate: ContractAddress) -> u256 {
            self.delegated_power.entry(delegate).read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _get_voting_power(self: @ContractState, user: ContractAddress) -> u256 {
            // This would call the VotingPower contract
            // For now, return a simplified calculation
            let delegated_power = self.delegated_power.entry(user).read();
            let base_power = 100; // Simplified base power
            base_power + delegated_power
        }

        fn _calculate_quorum(self: @ContractState, is_emergency: bool) -> u256 {
            let params = self.platform_parameters.read();
            let percentage = if is_emergency {
                params.emergency_quorum_percentage
            } else {
                params.quorum_percentage
            };
            
            // Simplified quorum calculation
            // In practice, this would be based on total voting power
            1000 * percentage.into() / 100
        }

        fn _execute_proposal_logic(ref self: ContractState, proposal_type: u8, proposal_id: u256) {
            match proposal_type {
                0 => { /* Platform Update logic */ },
                1 => { /* Fee Change logic */ },
                2 => { /* Policy Change logic */ },
                3 => { /* Emergency logic handled separately */ },
                4 => { /* Parameter Update logic */ },
                5 => { /* Governance Upgrade logic */ },
                _ => panic!("Invalid proposal type"),
            }
        }

        fn _execute_emergency_logic(ref self: ContractState, emergency_type: u8, proposal_id: u256) {
            match emergency_type {
                0 => { /* Security emergency */ },
                1 => { /* Critical bug fix */ },
                2 => { /* Economic emergency */ },
                _ => panic!("Invalid emergency type"),
            }
        }

        fn _is_emergency_council_member(self: @ContractState, user: ContractAddress) -> bool {
            let council = self.emergency_council.read();
            let mut is_member = false;
            let mut i = 0;
            let len = council.members.len();
            
            while i < len {
                if council.members.at(i) == user {
                    is_member = true;
                    break;
                }
                i += 1;
            };
            
            is_member
        }

        fn _has_governance_permission(self: @ContractState, user: ContractAddress) -> bool {
            // Check if user has governance permission through approved proposals
            // This is a simplified check
            false
        }

        fn _get_parameter_value(self: @ContractState, parameter_type: u8, params: PlatformParameters) -> u256 {
            match parameter_type {
                0 => params.fee_distribution_treasury.into(),
                1 => params.fee_distribution_providers.into(),
                2 => params.fee_distribution_governance.into(),
                3 => params.fee_distribution_development.into(),
                4 => params.min_voting_power,
                5 => params.min_proposal_duration.into(),
                6 => params.max_proposal_duration.into(),
                7 => params.emergency_voting_duration.into(),
                8 => params.time_lock_delay_normal,
                9 => params.time_lock_delay_emergency,
                10 => params.quorum_percentage.into(),
                11 => params.emergency_quorum_percentage.into(),
                _ => panic!("Invalid parameter type"),
            }
        }

        fn _update_parameter_by_type(
            ref self: ContractState,
            parameter_type: u8,
            new_value: u256,
            ref params: PlatformParameters
        ) {
            match parameter_type {
                0 => { params.fee_distribution_treasury = new_value.try_into().unwrap(); },
                1 => { params.fee_distribution_providers = new_value.try_into().unwrap(); },
                2 => { params.fee_distribution_governance = new_value.try_into().unwrap(); },
                3 => { params.fee_distribution_development = new_value.try_into().unwrap(); },
                4 => { params.min_voting_power = new_value; },
                5 => { params.min_proposal_duration = new_value.try_into().unwrap(); },
                6 => { params.max_proposal_duration = new_value.try_into().unwrap(); },
                7 => { params.emergency_voting_duration = new_value.try_into().unwrap(); },
                8 => { params.time_lock_delay_normal = new_value; },
                9 => { params.time_lock_delay_emergency = new_value; },
                10 => { params.quorum_percentage = new_value.try_into().unwrap(); },
                11 => { params.emergency_quorum_percentage = new_value.try_into().unwrap(); },
                _ => panic!("Invalid parameter type"),
            }
        }
    }
} 