# A basic staking mechanism on sui

A working version of a basic staking mechanism on sui.

The mechanism is based on lazy staking, where the state is updated on user actions, as opposed to the backend.

Lazy staking is based on the prefix sum algorithm.

The implementation can be extended with functionality to :
1. have the users hold their own funds in a wrapped token object
2. emit events 
3. freeze/unfreeze the pool
4. whitelist users
5. etc.
