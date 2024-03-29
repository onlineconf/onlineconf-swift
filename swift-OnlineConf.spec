Name:          swift-OnlineConf
Version:       %{__version}
Release:       %{!?__release:1}%{?__release}%{?dist}
Summary:       OnlineConf client

Group:         MAILRU
License:       MAILRU
URL:           https://gitlab.corp.mail.ru/mydev/%{name}
Source0:       %{name}-%{version}.tar.gz
BuildRoot:     %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildRequires: swift >= 5.0
BuildRequires: swift-packaging >= 0.10
BuildRequires: swiftpm(https://github.com/my-mail-ru/swiftperl.git) >= 1.1.0

%undefine _missing_build_ids_terminate_build
%swift_package_ssh_url
%swift_find_provides_and_requires

%description
OnlineConf client for Swift.

%{?__revision:Built from revision %{__revision}.}


%prep
%setup -q
sed -i 's/^let perl = false/let perl = true/' Package.swift
sed -i 's/^our \$VERSION = .*$/use version; our $VERSION = version->declare("v%{version}");/' Sources/OnlineConfPerl/OnlineConf.pm


%build
%swift_build


%install
rm -rf %{buildroot}
%swift_install
%swift_install_devel


%clean
rm -rf %{buildroot}


%files
%defattr(-,root,root,-)
%{swift_bindir}/*
%{swift_libdir}/*.so


%package devel
Summary:  Module and header file for OnlineConf client
Requires: swift-OnlineConf = %{version}-%{release}

%description devel
Module and header file for Swift OnlineConf client.

%{?__revision:Built from revision %{__revision}.}


%files devel
%defattr(-,root,root,-)
%{swift_moduledir}/*.swiftmodule
%{swift_moduledir}/*.swiftdoc
%{swift_clangmoduleroot}/CCKV


%package -n perl-MR-OnlineConf
Summary:   OnlineConf client
Epoch:     1
Requires:  swift-OnlineConf = %{version}-%{release}
Provides:  perl-MR-Onlineconf = 1:%{version}-%{release}
Obsoletes: perl-MR-Onlineconf

%description -n perl-MR-OnlineConf
OnlineConf client for Perl.

%{?__revision:Built from revision %{__revision}.}


%files -n perl-MR-OnlineConf
%defattr(-,root,root,-)
%{perl_vendorarch}/MR/OnlineConf.pm
%{perl_vendorarch}/auto/MR/OnlineConf/OnlineConf.so
