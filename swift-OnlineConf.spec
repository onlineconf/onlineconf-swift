Name:          swift-OnlineConf
Version:       %{__version}
Release:       %{!?__release:1}%{?__release}%{?dist}
Summary:       OnlineConf client

Group:         MAILRU
License:       MAILRU
URL:           https://gitlab.corp.mail.ru/mydev/%{name}
Source0:       %{name}-%{version}.tar.gz
BuildRoot:     %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildRequires: swift >= 3.0
BuildRequires: swift-packaging >= 0.6
BuildRequires: swiftpm(https://github.com/my-mail-ru/swiftperl.git) >= 0.3.0

%swift_package_ssh_url
%swift_find_provides_and_requires

%description
OnlineConf client for Swift.

%{?__revision:Built from revision %{__revision}.}


%prep
%setup -q
%swift_patch_package
sed -i 's/^our \$VERSION = .*$/use version; our $VERSION = version->declare("v%{version}");/' Sources/OnlineConfPerl/OnlineConf.pm


%build
%swift_build


%install
rm -rf %{buildroot}
%swift_install
%swift_install_devel
rm %{buildroot}%{swift_moduledir}/OnlineConfPerl.{swiftmodule,swiftdoc}
mkdir -p %{buildroot}%{perl_vendorarch}/MR/
cp Sources/OnlineConfPerl/OnlineConf.pm %{buildroot}%{perl_vendorarch}/MR/
mkdir -p %{buildroot}%{perl_vendorarch}/auto/MR/OnlineConf/
cp .build/release/libXS/OnlineConf.so %{buildroot}%{perl_vendorarch}/auto/MR/OnlineConf/


%clean
rm -rf %{buildroot}


%files
%defattr(-,root,root,-)
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
