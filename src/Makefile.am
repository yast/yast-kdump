# Sources for kdump

module_DATA = \
  modules/Kdump.rb

client_DATA = \
  clients/kdump_auto.rb \
  clients/kdump_finish.rb \
  clients/kdump_proposal.rb \
  clients/kdump.rb

yncludedir = @yncludedir@/kdump
ynclude_DATA = \
  include/kdump/wizards.rb \
  include/kdump/uifunctions.rb \
  include/kdump/dialogs.rb \
  include/kdump/complex.rb \
  include/kdump/helps.rb

scrconf_DATA = \
  scrconf/cfg_kdump.scr

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/kdump.rnc

desktop_DATA = \
  desktop/kdump.desktop

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(schemafiles_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common