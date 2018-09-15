module Bosh::Stemcell
  class Arch

    def self.arch
      RbConfig::CONFIG['host_cpu']
    end

    def self.ppc64le?
      arch == 'powerpc64le'
    end

    def self.x86_64?
      arch == 'x86_64'
    end

    def self.arm64v8?
      arch == 'aarch64'
    end
  end
end
