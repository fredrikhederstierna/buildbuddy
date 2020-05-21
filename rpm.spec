Name:           %{name}
Version:	1.0
Release:        1
Summary:        Buildbuddy toolchain
License:        OK
URL:            http://www.sau.no

%define __spec_install_post /usr/lib/rpm/brp-compress
%define __os_install_post /usr/lib/rpm/brp-compress
%define _rpmdir .
%define _source_payload w9.gzdio
%define _binary_payload w9.gzdio

%description
Buildbuddy toolchain for building firmware.
%{name}

%prep
exit 0

%build
exit 0

%install
mkdir -p %{buildroot}%{os_install_dir}
cp -R %{deploy_dir}/%{name} %{buildroot}%{os_install_dir}

%clean
exit 0

%files
%defattr(-,root,root)
%{os_install_dir}/%{name}
