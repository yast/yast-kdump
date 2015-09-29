#
# spec file for package yast2-kdump
#
# Copyright (c) 2014 SUSE LINUX Products GmbH, Nuernberg, Germany.
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
Version:        3.1.31
Release:        0
Summary:        Configuration of kdump
License:        GPL-2.0
Group:          System/YaST
Url:            https://github.com/yast/yast-kdump
Source0:        %{name}-%{version}.tar.bz2
BuildRequires:  perl-XML-Writer
BuildRequires:  rubygem(rspec)
BuildRequires:  rubygem(yast-rake)
BuildRequires:  update-desktop-files
BuildRequires:  yast2
# Wizard::SetDesktopTitleAndIcon
BuildRequires:  yast2 >= 2.21.22
BuildRequires:  yast2-bootloader
BuildRequires:  yast2-buildtools >= 3.1.10
BuildRequires:  yast2-packager >= 2.17.24
BuildRequires:  yast2-storage
BuildRequires:  yast2-testsuite
Requires:       yast2
# Kernel parameters with multiple values and bug#945479 fixed
Requires:       yast2-bootloader >= 3.1.148
Requires:       yast2-ruby-bindings >= 1.0.0
Requires:       yast2-storage
# SpaceCalculation.GetPartitionInfo
Requires:       yast2-packager
Recommends:     makedumpfile
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
%ifarch ppc
Recommends:     kdump
%else
Requires:       kdump
%endif

%description
Configuration of kdump

%prep
%setup -q

%check
rake test:unit

%build

%install
rake install DESTDIR="%{buildroot}"


%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/kdump
%{yast_yncludedir}/kdump/*
%dir %{yast_libdir}/kdump
%{yast_libdir}/kdump/*
%{yast_clientdir}/kdump.rb
%{yast_clientdir}/kdump_*.rb
%{yast_moduledir}/Kdump.*
%{yast_desktopdir}/kdump.desktop
%{yast_schemadir}/autoyast/rnc/kdump.rnc
%{yast_scrconfdir}/*.scr
%doc %{yast_docdir}
