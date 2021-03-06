class Video

  attr_accessor :action, :platform, :driver, :image_count, :seconds, :extended, :udid, :format

  def initialize options
    Flick::Checker.action options[:action]
    Flick::Checker.platform options[:platform]
    Flick::Checker.format options[:format]
    self.action = options[:action]
    self.platform = options[:platform]
    case self.platform
    when "ios"
      self.driver = Flick::Ios.new options
    when "android"
      self.driver = Flick::Android.new options
    end
    self.image_count = options[:count]
    self.seconds = options[:seconds].to_f
    self.extended = options[:extend].to_b
    self.udid = self.driver.udid
    self.format = options[:format]
  end

  def run
    self.send(action)
  end

  def start
    driver.clear_files
    if driver.recordable?
      Flick::Checker.system_dependency "mp4box"
      if extended
        puts "Starting Recorder In Extended Mode.\n"
        loop_record
      else
        puts "Starting Recorder In Normal Mode.\nRecorder will automatically stop after 180 seconds...\n"
        start_record
      end
    else
      Flick::Checker.system_dependency "ffmpeg"
      puts "Starting Screenshot Recorder...\n"
      start_screenshot_record
    end
  end

  def stop
    puts "\nStopping Recorder!!!"
    if driver.recordable?
      stop_record
    else
      stop_screenshot_recording
    end
    sleep 1
    driver.clear_files
  end

  private

  def android
    platform == "android"
  end

  def ios
    platform == "ios"
  end

  def start_record
    Flick::System.kill_process "video", udid
    $0 = "flick-video-#{udid}"
    SimpleDaemon.daemonize!
    command = -> do
       driver.screenrecord "video-single"
     end
    command.call
  end

  def loop_record
    Flick::System.kill_process "video", udid
    $0 = "flick-video-#{udid}"
    SimpleDaemon.daemonize!
    command = -> do
      count = "%03d" % 1
      loop do
        unless Flick::System.process_running? "#{udid}-"
          driver.screenrecord "video-#{count}"
          count.next!
        end
      end
    end
    command.call
  end

  def stop_record
    Flick::System.kill_process "video", udid #kills recording
    sleep 5 #wait for video process to completely finish on device.
    driver.pull_files "video" 
    files = Dir.glob("#{driver.flick_dir}/video*.mp4")
    if files.empty?
      puts "\nError! No video files found in #{driver.flick_dir}\n".red
      return
    end
    files.each { |file| system("mp4box -cat #{file} #{driver.flick_dir}/#{driver.name}.mp4") } #renames video-single to udid or name if given...
    puts "Saving to #{driver.outdir}/#{driver.name}.#{format}"
    if format == "gif"
      gif
    else
      File.rename "#{driver.flick_dir}/#{driver.name}.mp4", "#{driver.outdir}/#{driver.name}.mp4" #moves file from .flick to output dir.
    end
  end

  def start_screenshot_record
    Flick::System.kill_process "screenshot", udid
    puts "Process will stop after #{image_count} screenshots.\n"
    $0 = "flick-screenshot-#{udid}"
    SimpleDaemon.daemonize!
    command = -> do
      count = "%03d" % 1
      loop do
        if count.to_i <= image_count
          driver.screenshot "screenshot-#{count}"
          count.next!; sleep seconds
        else
          stop_screenshot_recording
          break
        end
      end
    end
    command.call
  end

  def stop_screenshot_recording
    driver.pull_files "screenshot" if android
    self.send(format)
    Flick::System.kill_process "screenshot", udid
    puts "Saving to #{driver.outdir}/#{driver.name}.#{format}"
  end

  def gif
    convert_images_to_mp4 unless driver.recordable?
    %x(ffmpeg -loglevel quiet -i #{driver.flick_dir}/#{driver.name}.mp4 -pix_fmt rgb24 #{driver.outdir}/#{driver.name}.gif)
  end

  def mp4
    convert_images_to_mp4
    File.rename "#{driver.flick_dir}/#{driver.name}.mp4", "#{driver.outdir}/#{driver.name}.mp4" unless format == "gif"
  end

  def convert_images_to_mp4
    remove_zero_byte_images
    %x(ffmpeg -loglevel quiet -framerate 1 -pattern_type glob -i '#{driver.flick_dir}/screenshot*.png' -c:v libx264 -pix_fmt yuv420p #{driver.flick_dir}/#{driver.name}.mp4)
    Flick::System.wait_for_file 30, "#{driver.flick_dir}/#{driver.name}.mp4"
  end

  def remove_zero_byte_images
    Dir.glob("#{driver.flick_dir}/screenshot*.png").each { |f| File.delete f if File.zero? f }
  end
end