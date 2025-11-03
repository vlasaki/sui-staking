# A basic staking mechanism for tokens

A working implementation of a basic staking mechanism for tokens.
The mechanism is based on lazy staking, where the state is updated on user actions, as opposed to the backend.
Lazy staking is based on the prefix sum algorithm.

The implementation can be extended with functionality to :
1. have the users hold their own funds in a wrapped token object
2. emit events 
3. freeze/unfreeze the pool
4. whitelist users
5. etc.
