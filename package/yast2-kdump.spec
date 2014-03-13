#
# spec file for package yast2-kdump
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-kdump
Version:        3.1.6
Release:        0

Url:            https://github.com/yast/yast-kdump
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:	        System/YaST
License:        GPL-2.0
Requires:	yast2 yast2-storage yast2-bootloader
BuildRequires:	perl-XML-Writer update-desktop-files yast2 yast2-testsuite yast2-storage yast2-bootloader
BuildRequires:  yast2-devtools >= 3.1.10
BuildRequires:  rubygem-rspec

Recommends:     kdump makedumpfile

# Wizard::SetDesktopTitleAndIcon
BuildRequires:	yast2 >= 2.21.22
BuildRequires: yast2-packager >= 2.17.24

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	Configuration of kdump

%description
Configuration of kdump

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install


%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/kdump
%{yast_yncludedir}/kdump/*
%{yast_clientdir}/kdump.rb
%{yast_clientdir}/kdump_*.rb
%{yast_moduledir}/Kdump.*
%{yast_desktopdir}/kdump.desktop
%{yast_schemadir}/autoyast/rnc/kdump.rnc
%{yast_scrconfdir}/*.scr
%doc %{yast_docdir}
