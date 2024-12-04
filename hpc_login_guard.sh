#!/bin/bash

# hpc_login_guard.sh
# B.Pietras, Nov '24

# This checks for %CPU use over ${cpu_trigger}
# on the login nodes (not meant for heavy lifting, just job submission)
# If found, it emails the user to stop, suggesting better methods.
# We could also use this to kill the pid as the user on the node (if wished).

# To avoid false positives from CPU spikes,
# each processes' %CPU is rechecked after 60 seconds.

# You need to change the node names and email info for your institution.

# %CPU to care about:
cpu_trigger=90
# Recheck after this many seconds:
gap=60

# Some tmpfiles to use & lose
tempo=$(mktemp)
tempo_plus1m=$(mktemp)
mailo=$(mktemp)
trap 'rm -rf "$tempo" "tempo_plus1m" "$mailo"; exit' ERR EXIT

# The nodes to scan over (just add/remove as you like - will work)
boxes=("login1.pri.barkla.alces.network" "login2.pri.barkla.alces.network" "login3.pri.barkla.alces.network")

for i in ${!boxes[@]}; do

  boxcut=$(echo ${boxes[i]} | cut -d '.' -f1)

  # (the fields are %CPU,PID,USER,COMMAND)
  ssh ${boxes[i]} 'ps -eo pcpu,pid,user,stime,args --no-headers| sort -t. -nk1,2 -k4,4 -r |head -n 5' >$tempo
  sleep $gap
  ssh ${boxes[i]} 'ps -eo pcpu,pid,user,stime,args --no-headers| sort -t. -nk1,2 -k4,4 -r |head -n 5' >$tempo_plus1m

  while read p; do
    cpu=$(echo $p | cut -d ' ' -f 1)
    pid=$(echo $p | cut -d ' ' -f 2)
    usr=$(echo $p | cut -d ' ' -f 3)

    # Should the process have ended within $gap, skip this line
    if ! grep -q "$pid" "$tempo_plus1m"; then
      break
    fi
    
    # Drop any non-system users, like alces-c+
    if ! ssh ${boxes[i]} id "$usr" >/dev/null 2>&1; then
      break
    fi
    
    # Should the process not belong to a user in 'clusterusers' primary group, skip this line
    group=$(ssh ${boxes[i]} id $usr | cut -d '(' -f3 | cut -d ')' -f1)
    if [[ "$group" != "clusterusers" ]]; then
      break
    fi
    
    p1m=$(grep $pid $tempo_plus1m)
    cpu_p1m=$(echo $p1m | cut -d ' ' -f 1)

    # Here any process over ${cpu_trigger}% of a CPU
    # for ${gap} seconds triggers an email alert
    if [ $(echo "$cpu_trigger < $cpu" | bc -l) -eq 1 ] && [ $(echo "$cpu_trigger < $cpu_p1m" | bc -l) -eq 1 ]; then
      
      name=$(ssh ${boxes[i]} getent passwd $usr | cut -d ':' -f 5|cut -d ' ' -f1)

      echo -e "Hi $name,\n\nI'm writing to you as we have detected high CPU usage by your process below:\n" >$mailo
      echo -e "%CPU PID User Start Cmd\n" >>$mailo
      echo -e $p"\n" >>$mailo
      echo -e "Please delete the process on $boxcut using\n\n\x27pkill $pid\x27\n\nand consider using either the batch system, a viz node or a slurm interactive job.\nThe login nodes are underpowered and high CPU usage affects the many users logged on.\n\nMany thanks,\nResearch IT" >>$mailo
      mail -s 'Login node, high CPU usage detected' -r hpc-support@liverpool.ac.uk -c $usr@liv.ac.uk hpc-support@liv.ac.uk <$mailo

    fi

  done <$tempo

done
