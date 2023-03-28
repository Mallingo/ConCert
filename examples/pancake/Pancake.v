(**  PancakeSwap Swap transaction
     Based on https://github.com/pancakeswap/pancake-smart-contracts/blob/master/projects/exchange-protocol/contracts/PancakeRouter.sol
     As well as: https://github.com/pancakeswap/pancake-smart-contracts/blob/master/projects/exchange-protocol/contracts/libraries/PancakeLibrary.sol
     & https://github.com/pancakeswap/pancake-smart-contracts/blob/master/projects/exchange-protocol/contracts/PancakePair.sol

     The code is combining the 3 contracts by traversing the swap function and implementing needed helper functions.
     The implementation is a simplified version and does not consider liquidity nor following a 'path' for swapping. eg. token -> BNB -> token

*)

From Coq Require Import ZArith_base.
From Coq Require Import List.
From Coq Require Import List. Import ListNotations.
From Coq Require Import Basics.
From Coq Require Import Lia.
From Coq Require Import Classes.RelationClasses.
From ConCert.Execution.Test Require Import QCTest.
From ConCert.Utils Require Import Automation.
From ConCert.Utils Require Import Extras.
From ConCert.Execution Require Import Monad.
From ConCert.Execution Require Import ResultMonad.
From ConCert.Execution Require Import Serializable.
From ConCert.Execution Require Import Blockchain.
From ConCert.Execution Require Import Containers.
From ConCert.Execution Require Import ContractCommon.
From ConCert.Utils Require Import Extras.
From ConCert.Utils Require Import RecordUpdate.

Open Scope Z.

Section Pancake.
    Context {BaseTypes : ChainBase}.
    Definition TokenValue := N.

    Open Scope N_scope.
    Open Scope bool.
    Open Scope address_scope.

    Set Nonrecursive Elimination Schemes.

    Definition Error : Type := nat.
    Definition default_error : Error := 1%nat.

    Record swap_param :=
      build_swap_param {
        value : TokenValue;
        amountOutMin: TokenValue;
        tokenA : Address;
        tokenB : Address;
        amount0 : TokenValue;
        amount1 : TokenValue;
        to : Address (* Address initiating the swap *)
    }.

    Record State :=
      build_state {
          pair : (Address * Address);
          created : bool;
          reserves : (TokenValue * TokenValue);
      }.

      Definition WETH := Address.
      Definition zero_address := Address.

    Definition error {T : Type} : result T Error :=
        Err default_error.

    Definition Result : Type := result (State * list ActionBody) Error.    

    Record Setup :=
        build_setup {
            init_address : Address;
            init_amount: TokenValue;
            pair_created: bool;
        }.

    (* begin hide *)
    MetaCoq Run (make_setters State).
    MetaCoq Run (make_setters swap_param).
    MetaCoq Run (make_setters Setup).

    Section Serialization.

    Global Instance setup_serializable : Serializable Setup :=
      Derive Serializable Setup_rect <build_setup>.

    Global Instance state_serializable : Serializable State :=
      Derive Serializable State_rect <build_state>.

    Axiom set_param_serializable : Serializable swap_param.
      Existing Instance set_param_serializable.

    End Serialization.
    (* end hide *)

    Definition init (chain : Chain)
                    (ctx : ContractCallContext)
                    (setup : Setup)
                    : result State Error :=
    Ok {| pair := (setup.(init_address), setup.(init_address));
          reserves := (setup.(init_amount), setup.(init_amount));
          created := setup.(pair_created)
    |}.
    
    Definition try_createPair (chain : Chain)
                              (ctx : ContractCallContext)
                              (tokenA: Address)
                              (tokenB: Address)
                              (param : swap_param)
                              (state: State)
                              : result State Error :=
    do _ <- throwIf (address_eqb tokenA tokenB) default_error; (* Pancake: IDENTICAL_ADDRESS*)

    do _ <- throwIf (state.(created)) default_error; (* Pancake: PAIR_EXISTS*)

    (* Could later on have the addLiqudity functionality.
       For now we manually set the liqudity for each token *)

    Ok(state<|created := true|>). 

    Definition set_initial_reserves (tokenA: Address)
                                    (tokenB: Address)
                                    (amountA: TokenValue)
                                    (amountB: TokenValue)
                                    (state: State)
                                    : result State Error :=
    do _ <- throwIf (amountA <? 0) default_error;
    do _ <- throwIf (amountB <? 0) default_error;
    let new_state := state<|reserves := (amountA, amountB)|> in 
    Ok(new_state).

    Definition get_reserves (tokenA: Address)
                            (tokenB: Address)
                            (state: State)
                            : (TokenValue * TokenValue) :=
    (fst state.(reserves) , snd state.(reserves)).
    
    (* Given input amount (BNB) and token pair reserves, returns the maximum output amount of the other asset*)
    Definition get_amount_out (amountIn: TokenValue)
                              (reserveIn: TokenValue)
                              (reserveOut: TokenValue)
                              : TokenValue :=
    (* Add check for input amount *)
    (* Add check for sufficient liquidity *)
    let amountInWithFee := amountIn * 9975 in
    let numerator := amountInWithFee * reserveOut in
    let denominator := reserveIn * 10000 + amountInWithFee in
    (numerator/denominator). (* Maximum output of asset *)
  
    Definition get_amounts_out (amountIn: TokenValue)
                               (tokenA: Address) 
                               (tokenB: Address)
                               (state: State)
                               : (TokenValue * TokenValue) := 
    let amount0 := amountIn in (* The amount of swapped BNB *)
    let (reserveIn, reserveOut) := get_reserves tokenA tokenB state in
    let amount1 := get_amount_out amount0 reserveIn reserveOut in
    (amount0, amount1).

    Definition real_swap (chain : Chain)
                         (ctx : ContractCallContext)
                         (state : State)
                         (param : swap_param)
                    : result State Error :=
    (* Require that amounts are greater than 0 *)
    do _ <- throwIf (param.(amount0) <? 0) default_error; (* Pancake: INSUFFICIENT_OUTPUT_AMOUNT*)
    do _ <- throwIf (param.(amount1) <? 0) default_error; (* Pancake: INSUFFICIENT_OUTPUT_AMOUNT*)
    
    let (reserve0, reserve1) := get_reserves param.(tokenA) param.(tokenB) state in

    (* Require that there is sufficient liquidity 
    do _ <- throwIf (reserve0 <? param.(amount0) ) default_error; (* Pancake: INSUFFICIENT_LIQUIDITY*)
    do _ <- throwIf (reserve1 <? param.(amount1) ) default_error; (* Pancake: INSUFFICIENT_LIQUIDITY*)
*)
    (* Require that 'to' address is not equal to the address of tokenA or tokenB *)
    do _ <- throwIf (address_eqb param.(to) param.(tokenA) ) default_error; (* Pancake: ZERO_ADDRESS*)
    do _ <- throwIf (address_eqb param.(to) param.(tokenB) ) default_error; (* Pancake: ZERO_ADDRESS*)
  
    (* Transfer the amount0 and amount1 *)

    (* Update the balance of tokenA and tokenB *)

    let balance0 := fst state.(reserves) in
    let balance1 := snd state.(reserves) in

    (* Update the reserves, eg. adding BNB (amount0) and subtracting the token swapped to *)

    let new_state := state<|reserves := (balance0 + param.(amount0), balance1 - param.(amount1))|> in 

    Ok(new_state).

    Definition swap_exact_tokens_for_eth (chain : Chain)
                                         (ctx : ContractCallContext)
                                         (state : State)
                                         (param : swap_param)
                                         : result State Error :=
    let cal_amount := get_amount_out param.(amount0) (snd state.(reserves)) (fst state.(reserves)) in
    let new_param := param<|amount0 := cal_amount|> in
    
    let balance0 := fst state.(reserves) in
    let balance1 := snd state.(reserves) in
    
    let new_state := state<|reserves := (cal_amount, balance1 + param.(amount1))|> in 

    Ok(new_state).

    Definition swap_exact_eth_for_tokens   (chain : Chain)
                                           (ctx : ContractCallContext)
                                           (state : State)
                                           (param : swap_param)
                                           : result State Error :=
    (* TokenA has to be BNB  *)
    (* do _ <- throwIf (address_eqb tokenA WETH) default_error; (* Pancake: INVALID_PATH*) *)                                        
    let (cal_amount0, cal_amount1) := get_amounts_out param.(value) param.(tokenA) param.(tokenB) state in
    let new_param := param<|amount0 := cal_amount0|><| amount1 := cal_amount1|> in 
    (* Require that the output amount is greater than our amountOutMin *)
    do _ <- throwIf (cal_amount1 <? (new_param.(amountOutMin))) default_error; (* Pancake: INSUFFICIENT_OUTPUT_AMOUNT*) 

    (* Conversion from BNB to WBNB happens here and is deposited *)

    (* Call the real_swap function to perform additional checks and update reserves *)
    real_swap chain ctx state new_param.

End Pancake.

Section Theories.
  Context {BaseTypes : ChainBase}.
  Open Scope N_scope.
  Open Scope bool.
  Open Scope address_scope.

    (* Initialization should always succeed *)
  Lemma init_is_some : forall chain ctx setup,
    exists state, init chain ctx setup = state.
    Proof.
      eauto.
    Qed.

  (* If the amountOutMin is higher than the swap amount an error is thrown  *)
  Lemma swap_exact_eth_for_tokens_invalid_amountoutmin :
  forall (chain : Chain)
         (ctx : ContractCallContext)
         (param: swap_param)
         (state : State),
         param.(amount1) <? param.(amountOutMin) = true ->
         param.(amount1) = get_amount_out (value param) (fst (reserves state))
         (snd (reserves state)) ->
    swap_exact_eth_for_tokens chain ctx state param  = error.
    Proof.
      intros chain ctx param state H1 H2.
      unfold swap_exact_eth_for_tokens.
      simpl. rewrite H2 in H1.
      rewrite H1. reflexivity.
    Qed.

 (* There should be an error if creating a pair with identical address *)
  Lemma try_createPair_identical_address : 
  forall (chain : Chain)
         (ctx : ContractCallContext)
         (tokenA tokenB : Address)
         (param : swap_param)
         (state: State),
    address_eqb tokenA tokenB = true -> try_createPair chain ctx tokenA tokenB param state = error.
    Proof.
        intros chain ctx tokenA tokenB param state H.
        unfold try_createPair.
        rewrite H. simpl.
        reflexivity.
    Qed.

  (* When creating a pair the created boolean should be set to true *)
  Lemma pair_created_updates_correctly :
  forall (chain : Chain)
         (ctx : ContractCallContext)
         (tokenA tokenB : Address)
         (param : swap_param)
         (reserves : (TokenValue * TokenValue)),
         (tokenA =? tokenB) = false ->
    let state := {| pair := (tokenA, tokenB); created := false; reserves := reserves |} in
    try_createPair chain ctx tokenA tokenB param state = 
      Ok (state<|created:=true|>).
      Proof.
        intros chain ctx tokenA tokenB param reserves H1.
        unfold try_createPair.
        rewrite H1. simpl. reflexivity.
    Qed.
   
    (* The reserves are updated after a eth -> token swap transaction*)
    Lemma swap_exact_eth_for_tokens_updates_reserves :
    forall (chain : Chain)
           (ctx : ContractCallContext)
           (tokenA tokenB to : Address)
           (param : swap_param),
    address_eqb to tokenA = false ->
    address_eqb to tokenB = false ->
    let state := {| pair := (tokenA, tokenB); created := true; reserves := (10,100000) |} in
    let param := {| amountOutMin := 1000; value := 1; tokenA := tokenA; tokenB := tokenB; amount0 := 0; amount1 := 0; to := to|} in
    let initial_reserves := get_reserves tokenA tokenB state in
    match swap_exact_eth_for_tokens chain ctx state param with
    | Err _ => False (* do nothing *)
    | Ok next_state =>
        let next_reserves := get_reserves tokenA tokenB next_state in
        initial_reserves <> next_reserves
    end.
  Proof.
    intros chain ctx tokenA tokenB to param h1 h2.
    unfold get_reserves.
    unfold swap_exact_eth_for_tokens. unfold real_swap.
    simpl. rewrite h1. rewrite h2. simpl. discriminate.
  Qed.

  (* The first step in proving that a frontrunning attack is possible.
     An actor would receive less amount of tokens when swapping after someone else has made the same swap *)
  Lemma similar_transaction_results_in_smaller_output :
  forall (chain : Chain)
         (ctx : ContractCallContext)
         (tokenA tokenB to : Address),
  address_eqb to tokenA = false ->
  address_eqb to tokenB = false ->
  let state := {| pair := (tokenA, tokenB); created := true; reserves := (10,100000) |} in
  let param := {| amountOutMin := 900; value := 1; tokenA := tokenA; tokenB := tokenB; amount0 := 1; amount1 := 5; to := to|} in
  let initial_reserves := get_reserves tokenA tokenB state in
  match swap_exact_eth_for_tokens chain ctx state param with
  | Err _ => False (* do nothing *)
  | Ok next_state =>
      let first_swap_amount := snd initial_reserves - snd next_state.(reserves) in
      match swap_exact_eth_for_tokens chain ctx next_state param with
      | Err _ => False (* do nothing *)
      | Ok next_state2 =>
      let next_reserves := get_reserves tokenA tokenB next_state2 in
      let second_swap_amount := snd next_state.(reserves) - snd next_reserves  in
      first_swap_amount > second_swap_amount
      end
  end.
  Proof.
    intros chain ctx tokenA tokenB to h1 h2.
    unfold get_reserves.
    unfold swap_exact_eth_for_tokens. unfold real_swap.
    simpl. rewrite h1. rewrite h2. simpl. reflexivity.
  Qed.


  Lemma swap_exact_tokens_for_eth_updates_reserves :
  forall (chain : Chain)
         (ctx : ContractCallContext)
         (tokenA tokenB to : Address)
         (param : swap_param),
  address_eqb to tokenA = false ->
  address_eqb to tokenB = false ->
  let state := {| pair := (tokenA, tokenB); created := true; reserves := (10,100000) |} in
  let param := {| amountOutMin := 1; value := 1; tokenA := tokenA; tokenB := tokenB; amount0 := 10000; amount1 := 10000; to := to|} in
  let initial_reserves := get_reserves tokenA tokenB state in
  match swap_exact_tokens_for_eth chain ctx state param with
  | Err _ => False (* do nothing *)
  | Ok next_state =>
      let next_reserves := get_reserves tokenA tokenB next_state in
      initial_reserves <> next_reserves
  end.
  Proof.
    intros chain ctx tokenA tokenB to param h1 h2.
    unfold get_reserves.
    unfold swap_exact_tokens_for_eth. unfold real_swap.
    simpl. unfold get_amount_out. discriminate.
  Qed.

  (* Swapping x amount of BNB to y amount of token Z and thereafter swapping y amount of
      token Z should return same amount of x BNB *)
  Lemma reversing_a_swap_results_in_initial_reserves :
  forall (chain : Chain)
         (ctx : ContractCallContext)
         (tokenA tokenB to : Address),
  address_eqb to tokenA = false ->
  address_eqb to tokenB = false ->
  let state := {| pair := (tokenA, tokenB); created := true; reserves := (100,1000000000) |} in
  let param1 := {| amountOutMin := 1000; value := 100; tokenA := tokenA; tokenB := tokenB; amount0 := 1; amount1 := 500; to := to|} in
  let initial_reserves := get_reserves tokenA tokenB state in
  match swap_exact_eth_for_tokens chain ctx state param1 with
  | Err _ => False (* do nothing *)
  | Ok next_state =>
      let first_swap_amount := snd initial_reserves - snd next_state.(reserves) in
      let param2 := {| amountOutMin := 9000; value := 0; tokenA := tokenA; tokenB := tokenB; amount0 := first_swap_amount; amount1 := first_swap_amount; to := to|} in
      match swap_exact_tokens_for_eth chain ctx next_state param2 with
      | Err _ => False (* do nothing *)
      | Ok next_state2 =>
          let next_reserves := get_reserves tokenA tokenB next_state2 in
          initial_reserves = next_reserves
      end
  end.
  Proof.
    intros chain ctx tokenA tokenB to h1 h2.
    simpl. unfold swap_exact_eth_for_tokens. unfold real_swap.
    simpl. rewrite h1. rewrite h2. simpl. unfold get_reserves. simpl. unfold get_amount_out. simpl.
    (* Have to figure out how to handle fee.
       Works if removing fee from get_amount_out function *)
    Admitted.
    

    (* The reserves are updated after a eth -> token swap transaction*)
    Lemma swap_exact_eth_for_tokens_updates_reserves_generic :
    forall (chain : Chain)
            (ctx : ContractCallContext)
            (param : swap_param)
            (state: State),
    address_eqb param.(to) param.(tokenA) = false ->
    address_eqb param.(to) param.(tokenB) = false ->
    param.(value) <? 0 = false ->
    get_amount_out (value param) (fst (reserves state))
    (snd (reserves state))  <? param.(amountOutMin) = false ->
    get_amount_out (value param) (fst (reserves state))
    (snd (reserves state))  <? 0 = false ->
    param.(value) > 0 ->
    let initial_reserves := get_reserves param.(tokenA) param.(tokenB) state in
    match swap_exact_eth_for_tokens chain ctx state param with
    | Err _ => False (* do nothing *)
    | Ok next_state =>
        let next_reserves := get_reserves param.(tokenA) param.(tokenB) next_state in
        initial_reserves = next_reserves
    end.
    Proof.
      intros chain ctx param state h1 h2 h3 h4 h5 h6.
      unfold get_reserves.
      unfold swap_exact_eth_for_tokens. unfold real_swap.
      simpl. rewrite h1. rewrite h2. rewrite h3. rewrite h4. rewrite h5. simpl.
      unfold get_amount_out. unfold reserves.
      
    Qed.


  (* An adversary picks up an actors swap transaction and fires an identical transaction beforehand *)
  Lemma adversary_makes_a_net_gain :
  forall (chain : Chain)
  (ctx : ContractCallContext)
  (tokenA tokenB to : Address),
  address_eqb to tokenA = false ->
  address_eqb to tokenB = false ->
  let state := {| pair := (tokenA, tokenB); created := true; reserves := (10,100000) |} in
  let param1 := {| amountOutMin := 900; value := 2; tokenA := tokenA; tokenB := tokenB; amount0 := 1; amount1 := 5; to := to|} in
  let param2 := {| amountOutMin := 1; value := 1; tokenA := tokenA; tokenB := tokenB; amount0 := 10000; amount1 := 10000; to := to|} in
  let initial_reserves := get_reserves tokenA tokenB state in
  match swap_exact_eth_for_tokens chain ctx state param1 with
    Err _ => False (* do nothing *)
    | Ok next_state =>
        let amount_swapped_adversary := snd initial_reserves - snd next_state.(reserves) in
        match swap_exact_tokens_for_eth chain ctx next_state param2 with
        | Err _ => False (* do nothing *)
        | Ok next_state2 =>
            let next_reserves := get_reserves tokenA tokenB next_state2 in
            let amount_swapped_actor := fst next_state2.(reserves) in
            amount_swapped_adversary > amount_swapped_actor
        end
    end.
  Proof.
    intros chain ctx tokenA tokenB to h1 h2.
    unfold get_reserves. simpl.
    unfold swap_exact_eth_for_tokens. unfold swap_exact_tokens_for_eth. unfold real_swap. 
    simpl. rewrite h1. rewrite h2. simpl. unfold get_amount_out. simpl.

End Theories.