In AWS, management accounts are divided into at least two levels. The first user to be created is Root, who has the highest authority and many risks, including possible credential leakage and data loss caused by misoperation, so it is not used as a daily operating account.

In any case, the administrator still needed to exist. So the IAM   admin management account based on minimum permissions was created for daily permission control, auditing or creating/allocating resources.

AWS will not supervise users' internal data, and users' own data needs to be managed and responsible by themselves. AWS only guarantees cloud infrastructure and provide framework support.This separation of user data and resource facilities management is called Shared Responsibility Model.
