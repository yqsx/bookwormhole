#!/bin/bash

# Step 1: Create the Ansible inventory file with groupings a, b, c and corresponding IP addresses as 'sip'
echo "Creating Ansible inventory file..."
cat <<EOL > inventory
[a]
nodea sip=198.0.0.1

[b]
nodeb sip=192.0.0.2

[c]
nodec sip=192.0.03
EOL

# Step 2: Configure Ansible to use the inventory file
echo "Configuring Ansible to use the inventory file..."
cat <<EOL > ansible.cfg
[defaults]
inventory = ./inventory
host_key_checking = False
EOL

# Step 3: Install required packages on all nodes
echo "Installing required packages on all nodes..."
ansible all -m shell -u root -a "yum install -y pcs pacemaker corosync fence-agents-all"

# Step 4: Configure firewall and enable pcsd service on all nodes
echo "Configuring firewall and enabling pcsd service..."
ansible all -m shell -u root -a "firewall-cmd --permanent --add-service=high-availability"
ansible all -m shell -u root -a "firewall-cmd --reload"
ansible all -m shell -u root -a "systemctl enable pcsd --now"

# Step 5: Set the hacluster user password on all nodes
echo "Setting hacluster user password on all nodes..."
ansible all -m shell -u root -a "echo redhat | passwd --stdin hacluster"

# Step 6: Authenticate nodes for pcs on one node (nodea)
echo "Authenticating nodes for pcs..."
ansible all -m shell -u root -a "pcs cluster auth nodea.private.example.com nodeb.private.example.com nodec.private.example.com -u hacluster -p redhat"

# Step 7: Setup and start the cluster on one node (nodea)
echo "Setting up and starting the cluster..."
ansible a -m shell -u root -a "pcs cluster setup --name cluster1 nodea.private.example.com nodeb.private.example.com nodec.private.example.com"
ansible a -m shell -u root -a "pcs cluster start --all"
ansible a -m shell -u root -a "pcs cluster enable --all"

# Step 8: Configure fencing on all nodes using the 'sip' variable
echo "Configuring fencing on all nodes..."
for i in a b c; do
  ansible $i -m shell -a \
  "pcs stonith create fence_node$i fence_ipmilan \
  pcmk_host_list=node$i.private.example.com \
  ip={{ sip }} \
  username=admin \
  password=password \
  lanplus=1 \
  power_timeout=180" -u root
done

# Final status check
echo "Cluster setup completed. Checking cluster status..."
ansible a -m shell -u root -a "pcs status"

echo "Cluster setup and fencing configuration completed successfully."
