
Pod::Spec.new do |s|

    s.name          = "SZDownload"
    s.version       = "1.0.1"
    s.summary       = "多任务断点续传下载"

    s.homepage      = "https://github.com/StenpZ/SZDownload"
    s.license       = "MIT"

    s.author        = { "StenpZ" => "zhouc520@foxmail.com" }
    s.source        = { :git => "https://github.com/StenpZ/SZDownload.git", :tag => "#{s.version}" }
    s.source_files  = "SZDownload/*.{h,m}"
    s.frameworks    = 'Foundation'
    s.platform      = :ios,'7.0'
    s.requires_arc = true

end
