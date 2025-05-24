Use case: You don't want to install bitwig via flatpak (sandboxed) on fedora as you want to use yabridge and vsts in general, maybe you tried to convert the 'Ubuntu' .deb to .rpm via alien but you had to force the rpm -i install and ended up with dependency mismatches that caused your dnf upgrades to fail.

To Install:

-  download latest 'Ubuntu' .deb of bitwig from their website: https://www.bitwig.com/download/#
-  clone this repo
-  execute 'sudo bitwig_deb2rpm_install.sh /path/to/bitwig.deb'
-  profit

Repeat the process above to update to the latest version, run the uninstall script to remove.

Use the vulkan fix script only on optimus machines.
