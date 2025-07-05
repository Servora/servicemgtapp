use starknet::ContractAddress;

#[starknet::interface]
trait IProposalManager<TContractState> {
    fn create_proposal(
        ref self: TContractState,
        title: felt252,
        description: ByteArray,
        proposal_type: u8,
        voting_duration: u64
    ) -> u256;
    fn vote_on_proposal(ref self: TContractState, proposal_id: u256, vote: bool);
    fn execute_proposal(ref self: TContractState, proposal_id: u256);
    fn get_proposal_details(self: @TContractState, proposal_id: u256) -> Proposal;
    fn get_proposal_count(self: @TContractState) -> u256;
}

#[derive(Drop, Serde, starknet::Store)]
struct Proposal {
    id: u256,
    title: felt252,
    description: ByteArray,
    proposer: ContractAddress,
    votes_for: u256,
    votes_against: u256,
    deadline: u64,
    executed: bool,
    proposal_type: u8, // 0: Platform Update, 1: Fee Change, 2: Policy Change
    created_at: u64,
}

#[starknet::contract]
mod ProposalManager {
    use super::{IProposalManager, Proposal};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };

    #[storage]
    struct Storage {
        proposals: Map<u256, Proposal>,
        proposal_count: u256,
        voter_has_voted: Map<(u256, ContractAddress), bool>,
        min_voting_power: u256,
        voting_power_contract: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ProposalCreated: ProposalCreated,
        VoteCast: VoteCast,
        ProposalExecuted: ProposalExecuted,
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalCreated {
        #[key]
        proposal_id: u256,
        #[key]
        proposer: ContractAddress,
        title: felt252,
        proposal_type: u8,
        deadline: u64,
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
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        voting_power_contract: ContractAddress,
        min_voting_power: u256
    ) {
        self.voting_power_contract.write(voting_power_contract);
        self.min_voting_power.write(min_voting_power);
        self.proposal_count.write(0);
    }

    #[abi(embed_v0)]
    impl ProposalManagerImpl of IProposalManager<ContractState> {
        fn create_proposal(
            ref self: ContractState,
            title: felt252,
            description: ByteArray,
            proposal_type: u8,
            voting_duration: u64
        ) -> u256 {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Validate proposal type
            assert(proposal_type <= 2, 'Invalid proposal type');
            
            // Validate voting duration (minimum 1 day, maximum 30 days)
            assert(voting_duration >= 86400 && voting_duration <= 2592000, 'Invalid voting duration');
            
            let proposal_id = self.proposal_count.read() + 1;
            self.proposal_count.write(proposal_id);
            
            let deadline = current_time + voting_duration;
            
            let proposal = Proposal {
                id: proposal_id,
                title,
                description,
                proposer: caller,
                votes_for: 0,
                votes_against: 0,
                deadline,
                executed: false,
                proposal_type,
                created_at: current_time,
            };
            
            self.proposals.entry(proposal_id).write(proposal);
            
            self.emit(ProposalCreated {
                proposal_id,
                proposer: caller,
                title,
                proposal_type,
                deadline,
            });
            
            proposal_id
        }

        fn vote_on_proposal(ref self: ContractState, proposal_id: u256, vote: bool) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Check if proposal exists
            let mut proposal = self.proposals.entry(proposal_id).read();
            assert(proposal.id != 0, 'Proposal does not exist');
            
            // Check if voting period is still active
            assert(current_time <= proposal.deadline, 'Voting period ended');
            
            // Check if user already voted
            assert(!self.voter_has_voted.entry((proposal_id, caller)).read(), 'Already voted');
            
            // Get voting power (simplified - would call external contract)
            let voting_power = self._get_voting_power(caller);
            assert(voting_power >= self.min_voting_power.read(), 'Insufficient voting power');
            
            // Record vote
            self.voter_has_voted.entry((proposal_id, caller)).write(true);
            
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
            assert(current_time > proposal.deadline, 'Voting still active');
            
            // Check if proposal passed (simple majority)
            let total_votes = proposal.votes_for + proposal.votes_against;
            assert(total_votes > 0, 'No votes cast');
            assert(proposal.votes_for > proposal.votes_against, 'Proposal failed');
            
            // Mark as executed
            proposal.executed = true;
            self.proposals.entry(proposal_id).write(proposal);
            
            // Execute proposal logic based on type
            self._execute_proposal_logic(proposal.proposal_type);
            
            self.emit(ProposalExecuted {
                proposal_id,
                votes_for: proposal.votes_for,
                votes_against: proposal.votes_against,
            });
        }

        fn get_proposal_details(self: @ContractState, proposal_id: u256) -> Proposal {
            self.proposals.entry(proposal_id).read()
        }

        fn get_proposal_count(self: @ContractState) -> u256 {
            self.proposal_count.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _get_voting_power(self: @ContractState, user: ContractAddress) -> u256 {
            // Simplified implementation - would call VotingPower contract
            // For now, return a default value
            100
        }

        fn _execute_proposal_logic(ref self: ContractState, proposal_type: u8) {
            // Implementation would depend on proposal type
            // This is where actual governance changes would be applied
            match proposal_type {
                0 => { /* Platform Update logic */ },
                1 => { /* Fee Change logic */ },
                2 => { /* Policy Change logic */ },
                _ => panic!("Invalid proposal type"),
            }
        }
    }
}
