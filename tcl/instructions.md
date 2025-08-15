 I have created the script setup_picore_wifi.sh in your current directory. Below
  are the detailed instructions on how to use it and get your Raspberry Pi online.

  ---

  How to Prepare Your Wi-Fi Files

  Step 1: Run the Script

  First, make the script executable and then run it. Open your terminal and
  execute these commands:

   1 chmod +x setup_picore_wifi.sh
   2 ./setup_picore_wifi.sh

  The script will create a directory named picore_wifi_files and handle
  everything: it downloads the 10 required packages and creates all the necessary
   configuration files and scripts, organizing them into a folder structure that
  mirrors the SD card layout.

  Step 2: Configure Your Wi-Fi Credentials

  This is the most important manual step. The script has created a template
  configuration file. You must edit it to add your Wi-Fi details.

   1. Open the following file in a text editor:
      picore_wifi_files/sd_card_files/tce/etc/wpa_supplicant.conf

   2. Inside the file, change these two lines to match your network:
       * ssid="Your_SSID"
       * psk="Your_Password"

   3. Save the file.

  Step 3: Copy Files to the SD Card

  Now, copy the generated files to your piCore-burned SD card.

   1. Insert the SD card into your computer.
   2. On the first partition (the boot partition):
       * Open the file cmdline.txt and add waitusb=5 to the end of the single line
         of text. This ensures the system waits for the SD card to be ready.

   3. On the second partition:
       * You will see a tce directory that piCore may have already created. If not,
          create it.
       * Copy the contents of the picore_wifi_files/sd_card_files/tce/ directory
         into the tce directory on the SD card.

      Your final structure on the SD card's second partition should look like this:


    1     tce/
    2     ├── onboot.lst
    3     ├── optional/
    4     │   ├── ca-certificates.tcz
    5     │   ├── firmware-rpi-wifi.tcz
    6     │   ├── libnl.tcz
    7     │   ├── ncurses.tcz
    8     │   ├── openssl.tcz
    9     │   ├── readline.tcz
   10     │   ├── wifi.tcz
   11     │   ├── wireless-6.1.69-piCore-v7l.tcz
   12     │   └── wireless_tools.tcz
   13     ├── etc/
   14     │   └── wpa_supplicant.conf  (Your edited version)
   15     └── opt/
   16         ├── bootlocal.sh
   17         └── mywifi.sh

  Step 4: Boot Up

  You are now ready to go.

   1. Safely eject the SD card from your computer.
   2. Insert it into your Raspberry Pi Zero 2 W and power it on.

  The Pi will now boot, automatically load all the required drivers and software,
   and run the script to connect to your Wi-Fi network. You can find its IP
  address from your router's admin page and ssh into it.




  Here is a step-by-step guide to find and mount your SD card.

  Step 1: Find Your SD Card Device

   1. Open a terminal.
   2. Run the following command before you plug in your USB SD card reader. This
      shows you the disks currently connected.

   1     lsblk

   3. Now, plug in your USB SD card reader.
   4. Run the same command again:

   1     lsblk

   5. Compare the output. You will see a new device, likely named /dev/sda,
      /dev/sdb, or /dev/sdc. This new device is your SD card. It will probably have
      two partitions listed under it (e.g., sdb1 and sdb2).

      Example `lsblk` output:

   1     NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
   2     ...
   3     sdb           8:16   1  29.7G  0 disk
   4     ├─sdb1        8:17   1   256M  0 part
   5     └─sdb2        8:18   1  29.5G  0 part
      In this example, the device is /dev/sdb. The boot partition is /dev/sdb1
  and the second partition is /dev/sdb2.

  Step 2: Mount the Partitions

  Once you've identified your device name, you need to mount its partitions to
  access the files.

   1. Create mount points: These are empty directories where the partitions will be
      mounted.

   1     sudo mkdir -p /mnt/pi_boot
   2     sudo mkdir -p /mnt/pi_root

   2. Mount the partitions: Replace /dev/sdX1 and /dev/sdX2 with the actual
      partition names you found in Step 1.

   1     # Mount the boot partition (the smaller, FAT32 one)
   2     sudo mount /dev/sdX1 /mnt/pi_boot
   3
   4     # Mount the root partition (the larger, ext4 one)
   5     sudo mount /dev/sdX2 /mnt/pi_root

  Step 3: Access Your Files

  You can now access the files on your SD card in the directories you created:
   * The boot partition files are in /mnt/pi_boot.
   * The second partition files (where you'll create the tce directory) are in
     /mnt/pi_root.

  Step 4: Unmount When Finished

  This is very important. Before you unplug the USB reader, you must unmount the
  partitions to prevent data corruption.

   1 sudo umount /mnt/pi_boot
   2 sudo umount /mnt/pi_root

  After unmounting, you can safely remove the SD card reader.
