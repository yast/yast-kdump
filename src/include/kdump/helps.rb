# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File:	include/kdump/helps.ycp
# Package:	Configuration of kdump
# Summary:	Help texts of all the dialogs
# Authors:	Jozef Uhliarik <juhliarik@suse.com>
#
# $Id: helps.ycp 27914 2006-02-13 14:32:08Z locilka $
module Yast
  module KdumpHelpsInclude
    def initialize_kdump_helps(_include_target)
      textdomain "kdump"

      # All helps are here
      @HELPS = {
        # Enable/Disable Kdump - RadioButtons 1/1
        "StartRadioBut"          => _(
          "<p><b>Enable/Disable Kdump</b><br>\n" \
            "    Enable or disable kdump. The \"crashkernel\" boot parameter is added/removed. \n" \
            "    To apply changes, a reboot is necessary.<br></p>\n"
        ),
        # Kdump Memor&y [MB] - IntField 1/1
        "KdumpMemory"            => _(
          "<p><b>Kdump Memory</b><br>\n    Allocation of memory for the kdump kernel.</p>"
        ) +
          _("<p>On AMD64/Intel 64 computers, the <i>High</i> value means reserving all " \
            "available memory. The <i>Low</i> value means reserving memory in the DMA32 zone, that "\
            "is, all the memory up to the 4 GB mark.<br>\n" \
            "<i>Low</i> is the amount of memory required by 32-bit-only devices. The kernel will allocate " \
            "64M for DMA32 bounce buffers. If your server does not have any 32-bit-only devices, " \
            "everything should work with the default allocation of 72M for <i>Low</i>. A possible " \
            "exception to this is on NUMA machines, which may make it appear that more Low memory is needed. " \
            "The Kdump kernel may be booted with numa=off to make sure normal kernel allocations do not use <i>Low</i> memory."),
        # fadump
        "FADump"                 => _(
          # T: help text for a combo box
          # description taken from http://lparbox.com/how-to/aix/19
          "<p><b>Firmware-Assisted Dump</b><br>\n" \
            "    Dumps are not generated before the partition is reinitialized but take place " \
            "    when the partition is restarting. When performing a firmware-assisted dump, " \
            "    system memory is frozen and the partition rebooted, which allows a new instance " \
            "    of the operating system to dump data from the previous kernel crash." \
            "    This feature is suitable only when the system has more than 1.5 GB of memory.</p>"
        ),
        # Kdump Memor&y [MB] - IntField 1/1
        "DumpLevel"              => _(
          "<p><b>Dump Level</b><br>\n" \
            "    Specify the type of necessary page for analysis.\n" \
            "    Pages of the specified type are copied to the dumpfile. \n" \
            "    The page type marked in the following table is included. <br></p>"
        ),
        # Dump Format - RadioButtons  1/1
        "DumpFormat"             => _(
          "<p><b>Dump Format</b><br>\n" \
            "    <i>No Dump</i> - Only save the kernel log.<br>\n" \
            "    <i>ELF Format</i> - Create dump file in ELF format.<br>\n" \
            "    <i>Compressed Format</i> - Compress dump data by each page with gzip.<br>\n" \
            "    <i>LZO Compressed Format</i> - Slightly bigger files but much faster.<br>\n</p>" \
            "    <i>Snappy Compressed Format</i> - Considerably faster, 64-bit optimized.<br>\n</p>" \
            "    <i>Zstandard Compressed Format</i> - Smaller files, slower.<br>\n</p>" \
            "    <i>Raw copy of /proc/vmcore</i> - does not use makedumpfile.<br>\n</p>"
        ),
        # Dump Format - RadioButtons  1/7
        "TargetKdump"            => _(
          "<p><b>Saving Target for Kdump Image</b><br>\n    The target for saving kdump images. Select the target type for saving dumps.<br></p>"
        ) +
          # Dump Format - RadioButtons  2/7
          _(
            "<p><b>Local Filesystem</b> - Save the kdump image in the local filesystem.\n" \
              "    <i>Directory for Saving Dumps</i> - The path for saving kdump images.\n" \
              "    Selecting directory for saving kdump images via dialog by pressing <i>Browse</i>\n" \
              "    <br></p>"
          ) +
          # Dump Format - RadioButtons  3/7
          _(
            "<p><b>FTP</b> - Save kdump image via FTP.\n" \
              "    <i>Server Name</i> - The name of the ftp server.\n" \
              "    <i>Port</i> - The port number for the connection.\n" \
              "    <i>Directory on Server</i> - The path for saving kdump images.\n" \
              "    <i>Enable Anonymous FTP</i> enables anonymous connection to the server.\n" \
              "    <i>User Name</i> for ftp connection. <i>Password</i> for ftp connection.<br></p>"
          ) +
          # Dump Format - RadioButtons  4/7
          _(
            "<p><b>SSH</b> - Save kdump image via SSH and 'dd' on target machine.\n" \
              "    <i>Server Name</i> - The name of the server.\n" \
              "    <i>Port</i> - The port number for the connection.\n" \
              "    <i>Directory on Server</i> - The path for saving kdump images.\n" \
              "    <i>User Name</i> for SSH connection.  \n" \
              "    <i>Password</i> for SSH connection.<br></p>\n"
          ) +
          # Dump Format - RadioButtons  5/7
          _(
            "<p><b>SFTP</b> - Save kdump image via SFTP.\n" \
              "    <i>Server Name</i> - The name of the server.\n" \
              "    <i>Port</i> - The port number for the connection.\n" \
              "    <i>Directory on Server</i> - The path for saving kdump images.\n" \
              "    <i>User Name</i> for SSH connection.  \n" \
              "    <i>Password</i> for SSH connection.<br></p>\n"
          ) +
          _(
            "<p>The choice between SSH and SFTP depends\n" \
            "on details of server configuration. SLE servers support both\n" \
            "by default.</p>"
          ) +
          # Dump Format - RadioButtons  6/7
          _(
            "<p><b>NFS</b> - Save kdump image on NFS.\n" \
              "    <i>Server Name</i> - The name of the nfs server.\n" \
              "    <i>Directory on Server</i> - The path for saving kdump images.<br></p>"
          ) +
          # Dump Format - RadioButtons  7/7
          _(
            "<p><b>CIFS</b> - Save kdump image via CIFS.\n" \
              "    <i>Server Name</i> - The name of the server.\n" \
              "    <i>Exported Share</i> - The windows share name.\n" \
              "    <i>Directory on Server</i> - The path for saving kdump images.\n" \
              "    <i>Use Authentication</i> enables authenticated connection to the server.\n" \
              "    <i>User Name</i> for the connection. <i>Password</i> for the connection.<br></p>"
          ),
        # Custom Kdump Kernel - TextEntry 1/1
        "InitrdKernel"           => _(
          "<p><b>Custom Kdump Kernel</b> The user can enter the custom kernel.\n" \
            "    The naming scheme is:<i>/boot/vmlinu[zx]-<kernel_string>[.gz]</i>\n" \
            "    Please enter only <i>kernel_string</i>.<br></p>"
        ),
        # Kdump Command Line - TextEntry 1/1
        "KdumpCommandLine"       => _(
          "<p><b>Kdump Command Line</b>\n    Additional arguments passed to kexec. <br></p>"
        ),
        # Kdump Command Line Append - TextEntry 1/1
        "KdumpCommandLineAppend" => _(
          "<p><b>Kdump Command Line Append</b>\n" \
            "    Set this option to _append_ values to the default command line string. \n" \
            "    The string will be appended if the <i>Kdump Command Line</i>\n" \
            "    is set. <br></p>\n"
        ),
        # Enable Immediate Reboot After Saving the Core - CheckBox 1/1
        "EnableReboot"           => _(
          "<p><b>Enable Immediate Reboot After Saving the Core</b> - \n    Enable immediate reboot after saving the core in the kdump.<br></p>"
        ),
        # Enable Delete Old Dump Images - CheckBox 1/1
        "EnableDeleteImages"     => _(
          "<p><b>Enable Delete Old Dump Images</b> - \n" \
            "    Enable Delete Old Dump Images. If the number of dump files in \n" \
            "    <i>Number of Old Dumps</i> exceeds this number, older dumps are removed.<br></p>"
        ),
        # SMTP Server
        "SMTPServer"             => _(
          "<p><b>SMTP Server</b> used for sending a notification email after a dump.</p>"
        ),
        # SMTP User Name
        "SMTPUser"               => _(
          "<p><b>User Name</b> for SMTP authentication when <i>SMTP Server</i> is\n  set. This is optional. If you do not specifiy a username and password, plain SMTP will be used.</p>\n"
        ),
        # SMTP Password
        "SMTPPassword"           => _(
          "<p><b>Password</b> for SMTP authentication when <i>SMTP Server</i> is set. This\n  is optional. If you do not specify a username and password, plain SMTP will be used.</p>\n"
        ),
        # Notification To (email addresses)
        "NotificationTo"         => _(
          "<p><b>Notification To</b> Specify the email address to which a notification email will be sent when a dump has been saved.</p>\n"
        ),
        # Notification CC (email addresses)
        "NotificationCC"         => _(
          "<p><b>Notification CC</b> Specify a list of space-separated email addresses to\n which a notification email will be sent via cc if a dump has been saved.</p>\n"
        ),
        # Number of Old Dumps (number)
        "NumberDumps"            => _(
          "<p><b>Number of Old Dumps</b> specifies how many old dumps are kept. If the number of dump files \nexceeds this number, older dumps are removed.</p>"
        ),
        # Read dialog help 1/2
        "read"                   => _(
          "<p><b><big>Initializing Kdump Configuration</big></b><br>\nPlease wait...<br></p>\n"
        ) +
          # Read dialog help 2/2
          _(
            "<p><b><big>Aborting Initialization:</big></b><br>\nSafely abort the configuration utility by pressing <b>Abort</b> now.</p>\n"
          ),
        # Write dialog help 1/2
        "write"                  => _(
          "<p><b><big>Saving Kdump Configuration</big></b><br>\nPlease wait...<br></p>\n"
        ) +
          # Write dialog help 2/2
          _(
            "<p><b><big>Aborting Saving:</big></b><br>\n" \
              "Abort the save procedure by pressing <b>Abort</b>.\n" \
              "An additional dialog informs whether it is safe to do so.\n" \
              "</p>\n"
          ),
        # Summary dialog help 1/3
        "summary"                => _(
          "<p><b><big>Kdump Configuration</big></b><br>\nConfigure kdump here.<br></p>\n"
        ) +
          # Summary dialog help 2/3
          _(
            "<p><b><big>Adding a Kdump:</big></b><br>\n" \
              "Choose an kdump from the list of detected kdumps.\n" \
              "If your kdump was not detected, select <b>Other (not detected)</b>.\n" \
              "Then press <b>Configure</b>.</p>\n"
          ) +
          # Summary dialog help 3/3
          _(
            "<p><b><big>Editing or Deleting:</big></b><br>\n" \
              "If you press <b>Edit</b>, an additional dialog in which to change\n" \
              "the configuration opens.</p>\n"
          ),
        # Ovreview dialog help 1/3
        "overview"               => _(
          "<p><b><big>Kdump Configuration Overview</big></b><br>\n" \
            "Obtain an overview of installed kdumps. Additionally\n" \
            "edit their configurations.<br></p>\n"
        ) +
          # Ovreview dialog help 2/3
          _(
            "<p><b><big>Adding a Kdump:</big></b><br>\nPress <b>Add</b> to configure a kdump.</p>"
          ) +
          # Ovreview dialog help 3/3
          _(
            "<p><b><big>Editing or Deleting:</big></b><br>\n" \
              "Choose a kdump to change or remove.\n" \
              "Then press <b>Edit</b> or <b>Delete</b> as desired.</p>\n"
          )
      }
    end

    def HelpKdump(identification)
      Ops.get_string(
        @HELPS,
        identification,
        Builtins.sformat("Help for '%1' is missing!", identification)
      )
    end
  end
end
