#  Copyright (c) 2013-2014 SUSE LLC
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 3 of the GNU General Public License as
#  published by the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.
#
#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

class BurndownChart

  attr_accessor :data

  def initialize(settings)
    @settings = settings
    @burndown_data = BurndownData.new settings

    @data = {
      "meta" => {
        "board_id" => nil,
        "sprint" => 1,
        "total_days" => 10,
        "weekend_lines" => [ 3.5, 8.5 ]
      },
      "days" => []
    }
  end

  def sprint
    @data["meta"]["sprint"]
  end

  def sprint= s
    @data["meta"]["sprint"] = s
  end

  def board_id
    @data["meta"]["board_id"]
  end

  def board_id= id
    @data["meta"]["board_id"] = id
  end

  def days
    @data["days"]
  end

  def initialize_entry(burndown_data, date)
    {
      "date" => date.to_s,
      "story_points" => {
        "total" => burndown_data.story_points.total,
        "open" => burndown_data.story_points.open
      },
      "tasks" => {
        "total" => burndown_data.tasks.total,
        "open" => burndown_data.tasks.open
      },
      "story_points_extra" => {
        "done" => burndown_data.extra_story_points.done
      },
      "tasks_extra" => {
        "done" => burndown_data.extra_tasks.done
      }
    }
  end

  def replace_entry(date, new_entry)
    days.each_with_index do |entry, idx|
      days[idx] = new_entry if entry["date"] == date.to_s
    end
  end

  def entry_exists?(date)
    days.any? { |entry| entry["date"] == date.to_s }
  end

  def add_data(burndown_data, date)
    new_entry = initialize_entry(burndown_data, date)
    if entry_exists?(date)
      replace_entry(date, new_entry)
    else
      days.push(new_entry)
    end
  end

  def read_data filename
    @data = YAML.load_file filename
  end

  def write_data filename
    @data["days"].each do |day|
      [ "story_points_extra", "tasks_extra" ].each do |key|
        if day[key] && day[key]["done"] == 0
          day.delete key
        end
      end
    end

    begin
      File.open( filename, "w" ) do |file|
        file.write @data.to_yaml
      end
    rescue Errno::ENOENT
      raise TrolloloError.new( "'#{filename}' not found" )
    end
  end

  def burndown_data_filename
    "burndown-data-#{sprint.to_s.rjust(2,"0")}.yaml"
  end

  def setup(burndown_dir, board_id)
    self.board_id = board_id
    FileUtils.mkdir_p burndown_dir
    write_data File.join(burndown_dir, burndown_data_filename)
  end

  def last_sprint(burndown_dir)
    last_sprint = sprint
    Dir.glob("#{burndown_dir}/burndown-data-*.yaml").each do |file|
      file =~ /burndown-data-(.*).yaml/
      current_sprint = $1.to_i
      if current_sprint > last_sprint
        last_sprint = current_sprint
      end
    end
    last_sprint
  end

  def load_last_sprint(burndown_dir)
    self.sprint = last_sprint(burndown_dir)
    burndown_data_path = File.join(burndown_dir, burndown_data_filename)
    read_data burndown_data_path
    return burndown_data_path
  end

  def update(burndown_dir)
    burndown_data_path = load_last_sprint(burndown_dir)
    @burndown_data.board_id = board_id
    @burndown_data.fetch
    add_data(@burndown_data, Date.today)
    write_data burndown_data_path
  end

  def create_next_sprint(burndown_dir)
    load_last_sprint(burndown_dir)
    self.sprint = self.sprint + 1
    @data["days"] = []
    write_data File.join(burndown_dir, burndown_data_filename)
  end
end
