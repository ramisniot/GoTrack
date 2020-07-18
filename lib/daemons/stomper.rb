#!/usr/bin/env ruby
$running_daemon = true # NOTE - hint to use class caching in dev mode
require 'numerex_stomper'
NumerexStomper::Daemon.run(__FILE__)
