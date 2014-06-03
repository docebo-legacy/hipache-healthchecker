hipache-healtchecker
====================

a ruby based health checker POC for @Dotcloud Hipache, based upon @Celluloid

INSTALLATION
================
:\>git clone https://github.com/docebo/hipache-healthchecker
:\>cd hipache-healthchecker
:\hipache-healthchecker>bundle install

USAGE
======
:\hipache-healthchecker> ruby hipache-healthcheck.rb

TODO
========

- write better doc
- some params would be nice
- set params for "fall" and "rise" for each backend, like "wait <x> failed check before marking the backend as DEATH" or "wait for <y> successful check before setting the backend back between the alive ones"