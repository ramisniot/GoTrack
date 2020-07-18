# GoTrack WebApp

## Deploy

Deploy to `dev` and `stg` environments will be done automatically when pushing changes into `develop` and `master` branch respectively

### ENV variables

If new `ENV` vars are included, they need to be added directly in the env vars configuration on the corresponding heroku app or it can be done with `figaro`.

Create a local copy of `config/application.sample.yml` into `config/application.yml` and fill all the needed env variables.

Execute `figaro heroku:set -e ${ENV}` to set all the defined vars into the corresponding heroku app
