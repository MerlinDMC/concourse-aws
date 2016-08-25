# Terraform infrastucture configuration for Concourse

The configuration in `infrastructure/` will create a very basic concourse setup on AWS with RDS as the primary database.
It will use basic-auth with the folowinf credentials:
```
username: concourse
password: ci
```

> This is not meant to be a ready secure production grade installation. It is mearly a fast way to start concourse up and have some play time.
