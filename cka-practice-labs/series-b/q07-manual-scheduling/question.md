# Stop the scheduler and schedule a Pod manually

Work on the control-plane node.

1. **Temporarily** stop `kube-scheduler` in a reversible way.
2. Create a Pod named `manual-schedule` in `default`, image `httpd:2-alpine`,
   and confirm it stays Pending without a node assignment.
3. Acting as the scheduler, assign that Pod to the worker node recorded in
   `./node.txt`, and make sure
   it runs.
4. Start `kube-scheduler` again and confirm its static Pod is Running.
5. Create a second Pod `manual-schedule2`, image `httpd:2-alpine`, and confirm
   the scheduler assigns it to a node by itself.

Do not change node taints or labels.
