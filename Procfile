web: puma -C config/puma.rb
worker: foreman start -f Procfile.workers
release: rake db:migrate
