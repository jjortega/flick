module Flick
  module System

    include Sys #load sys-proctable methods

    def self.setup_system_dir dir_name
      Dir.mkdir dir_name unless File.exists? dir_name
    end

    def self.clean_system_dir dir_name
      Dir.glob("#{dir_name}/*").each { |file| File.delete file }
    end

    def self.find_pid string
      processes = ProcTable.ps.find_all { |x| x.cmdline.include? string }
      processes.map { |p| p.pid } rescue []
    end

    def self.kill_pids pid_array
      return if pid_array.empty?
      pid_array.each { |p| Process.kill 'SIGKILL', p }
    end

    def self.process_running? string
      pid = self.find_pid string
      unless pid.empty?
        puts "PROCESSING IS RUNNING!!!"
        true
      else
        false
      end
    end

    def self.kill_process type, udid
      pids = self.find_pid "#{type}-#{udid}"
      self.kill_pids pids
      if type == "video"
        pid = `pgrep -f #{udid}`.to_i
        `kill #{pid}` unless pid.zero?
      end
    end

    def self.kill string
      pids = self.find_pid string
      self.kill_pids pids
    end
    
    def self.wait_for_file time, file
      start = Time.now
      until File.exists? file
        puts "Waiting for #{file} to exist..."
        sleep 1; break if Time.now - start > time
      end
    end

    def self.video_length file
      (`ffmpeg -i #{file} 2>&1 | grep Duration | cut -d ' ' -f 4 | sed s/,//`).strip
    end
  end
end