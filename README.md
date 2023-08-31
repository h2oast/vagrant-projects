# vagrant-projects
projects for quickly deploy a develop or test cluster of vitrual machines

# vagrant plugin
  to provision the vagrant boxes successfully, you need to install several
  plugin as following:
```bash
# install plugin 'env' and 'vagrant-env' for vagrant, this need not to be 
#  executed as root, just execute it as regular user.
vagrant plugin install --plugin-clean-sources                               \
                       --plugin-source https://gems.ruby-china.com/         \
                       vagrant-env
```
