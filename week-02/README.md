"Action": ["s3:PutObject", "s3:GetObject"],
"Resource": "arn:aws:s3:::my-training-bucket-<yourname ky>/*"

Put and Get This means that files can be uploaded or read (downloaded) in s3 bucket.
But the files(resource) are limited to the s3 bucket which name of my-training-bucket-<yourname ky>/*

When/* is used, get and put means read and write the internal files of the bucket, but without/*, the modification operation will become the attribute of the bucket itself (general accounts usually don't want this, because it is something that administrators do).