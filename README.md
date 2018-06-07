Persiqueue
----------

Test implementation of persistent queue with the next possibilities:

- Add message in the end of the queue (add)
- Get the next message from the beginning of the queue for processing (get)
- Acknowledge successful processing of the message (ack)
- Reject processing of the message and add the message back in the end of the queue (reject)

There may be several message processors and they could work independently.

Assumptions
-----------

- All nodes are predefined in a config file.
- All nodes are being running on the same host machine.
- All nodes should be run together before starting to use the queue.
- In case some node will fall down and rise up again it could be mark as inconsistent.

Usage
-----

Run all predefined nodes by using such command on each appropriate node:
```
iex --sname <nodeN> --cookie persiqueue -S mix
```
