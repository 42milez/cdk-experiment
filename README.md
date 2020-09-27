# cdk-experiment
[![Build Status](https://travis-ci.org/42milez/cdk-experiment.svg?branch=master)](https://travis-ci.org/42milez/cdk-experiment)

cdk-experiment is an experimental project template based on AWS CDK. This project aims easy deployment of AWS resources that is generally used for web application.

## Features
- Multi CFn stack support
- Multi Lambda layer support
- Multi stage support (dev/stg/prod)
- etc.

## Quick Start
⚠️ [Named profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html) is required when creating CFn stack. Named profile can be specified as `cli.profile` key in `cmd/config.yml`.

```
docker-compose build
docker-compose run --rm npm install
./cmd/code.sh build --env development
./cmd/cdk.sh bootstrap
./cmd/cdk.sh deploy --env development --stack 'service1,service2'
```

## Commands

⚠️ `development` is used as default when `--env` option is not specified.

#### Checking Code Style
```
./cmd/code.sh lint
```

#### Building Sources
```
./cmd/code.sh build
```

#### Deploying the CDK toolkit stack
```
./cmd/cdk.sh bootstrap
```

#### Printing manifest
```
./cmd/cdk.sh list --env development
```
###### Available options:
- `--env`: either `development`, `staging` or `production`

#### Deploying the stacks
```
./cmd/cdk.sh deploy --env development --stack 'service1,service2'
```
###### Available options:
- `--env`: either `development`, `staging` or `production`
- `--stack`

#### Printing the CloudFormation template
```
./cmd/cdk.sh deploy --env development --stack 'service1,service2'
```
###### Available options:
- `--env`: either `development`, `staging` or `production`
- `--stack`

#### Destroying the stacks

```
./cmd/cdk.sh destroy --env development --stack 'service1,service2'
```
###### Available options:
- `--env`: either `development`, `staging` or `production`
- `--stack`
