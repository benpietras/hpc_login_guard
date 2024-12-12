HPC Login Guard
====
A perpetual bugbear of HPC is users running heavy lifting on the login nodes, slowing down the service for everyone else. 
This could run hourly as a cronjob, emailing users to stop. It checks the process is still above threshold after x seconds, to ignore CPU spikes. 

E.g., to run every half hour via cron:

```*/30  * * * * /usr/local/bin/scripts/hpc_login_guard.sh 2>&1```

Requirements on the linux server to run it:
* Cron access for your user
* ssh key access to the login nodes
* 'mail' configured to allow sending emails from the cli
  
That's it. No admin access necessary.

There are some comments to explain in the code, but basically it works like this:
1) Read the top 5 CPU processes of the node
2) Wait 1 minute
3) Read the top 5 CPU processes of the node
4) Skip in the case that the process is:
    * Not owned by a user in a group 'clusterusers' (that all our users are in)
    * Not above 90 %CPU in both readings
5) If the process isn't skipped, then email the user (appearing from our team email) to suggest better ways of working.
6) Once the top 5 processes are looped over, loop to the next listed node.

The script should be quite adaptable, you can add as many nodes as you like to scan (dynamic array), as many top processes, change the %CPU threshold, time to measure over, number of times to measure, etc.
