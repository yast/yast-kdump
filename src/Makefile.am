# Makefile.am for kdump/src

yncludedir = @yncludedir@/kdump

client_DATA =			\
	kdump.ycp		\
	kdump_auto.ycp		\
	kdump_proposal.ycp	\
	kdump_finish.ycp

ynclude_DATA =			\
	helps.ycp		\
	wizards.ycp		\
	dialogs.ycp		\
	complex.ycp		\
	uifunctions.ycp

desktop_DATA =			\
	kdump.desktop

module_DATA =			\
	Kdump.ycp

# create a symlink for local build, #145327
kdump:
	ln -sf . $@
ycpchook = kdump

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
