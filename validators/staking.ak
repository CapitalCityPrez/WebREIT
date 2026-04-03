use aiken/collection/list
use cardano/address.{PaymentCredential, VerificationKeyHash}
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/transaction.{InlineDatum, OutputReference, Transaction}
use cardano/time.{POSIXTime}

pub type Datum {
  owner: VerificationKeyHash,
  staked_at: POSIXTime,
  nft_policy: PolicyId,
  nft_name: AssetName,
}

pub type Redeemer {
  Unstake
}

validator nft_staker(nft_policy_id: PolicyId) {
  spend(datum_opt: Option<Datum>, redeemer: Redeemer, own_ref: OutputReference, self: Transaction) {
    expect Some(datum) = datum_opt   // must have datum

    let Transaction { inputs, outputs, extra_signatories, .. } = self

    when redeemer is {
      Unstake -> {
        // 1. Only the recorded owner can unstake
        expect list.has(extra_signatories, datum.owner)

        // 2. Find the staked NFT in the input being spent
        expect Some(own_input) =
          list.find(inputs, fn(i) { i.output_reference == own_ref })

        // 3. Verify this UTxO actually holds the exact NFT we're staking
        let nft_value = Value::new_with(datum.nft_policy, datum.nft_name, 1)
        expect own_input.output.value >= nft_value

        // 4. (Optional but recommended) Ensure the NFT is returned to the owner
        //     in the same transaction (prevents accidental loss)
        let owner_cred = PaymentCredential::VerificationKey(datum.owner)
        let nft_returned = list.any(outputs, fn(out) {
          out.address.payment_credential == owner_cred &&
          out.value >= nft_value
        })
        expect nft_returned

        // Success! NFT is unlocked and returned to owner
        True
      }
    }
  }
}
