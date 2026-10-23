Strictly speaking, my laptop doesn't have any traffic into aws's private network, because all operations are done on another virtual machine in ec2.
My laptop can directly access the ec2 virtual machine with the public ip address, and the public virtual machine can access the private instance through the aws internal private ip. This public instance is called Bastion host or jump server, which acts as an intermediary to access the internal virtual machine or service.

In fact, in week4, we used a similar method to access mysql database, because this database did not allow public access.