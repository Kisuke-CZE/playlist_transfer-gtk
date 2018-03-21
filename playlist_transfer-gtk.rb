#!/usr/bin/env ruby

require 'gtk3'
require 'pathname'
require 'm3u8'
require 'playlist_transfer'

class PlaylistTransferGUI

  def initialize(glade_path)
    @builder = Gtk::Builder.new
    @builder.add_from_file(glade_path)
    @builder.connect_signals { |handler| method (handler) }
    @main_window = @builder.get_object('mainwindow')
  end

  def run
    @main_window.show
    Gtk.main
  end

  def quit
    Gtk.main_quit
  end

  def musicdir_selector_activate
    musicdir_enabled = @builder.get_object('specify_musicdir_switch')
    music_chooser = @builder.get_object('choose_musicdir')
    music_chooser.set_sensitive(musicdir_enabled.active?)
    return false
  end

  def show_error(message)
    error_window = @builder.get_object('error_dialog')
    error_window.text = "#{message}"
    error_window.show
  end

  def close_error
    error_window = @builder.get_object('error_dialog')
    error_window.hide
  end

  def cancel
    @exit = true
  end

  def update_ui
    while Gtk.events_pending?
        Gtk.main_iteration
    end
  end

  def start_transfer
    @transfer_proc = Thread.new { run_transfer }
  end

  def run_transfer
    compatible_sw = @builder.get_object('compatible_switch')
    justcopy_sw = @builder.get_object('justcopy_switch')
    use_musicdir_sw = @builder.get_object('specify_musicdir_switch')
    playlist_diag = @builder.get_object('choose_playlist')
    output_diag = @builder.get_object('choose_output')
    progressbar = @builder.get_object('progressbar')
    run_button = @builder.get_object('run_button')
    progressbar.set_fraction(0)
    cancel_button = @builder.get_object('cancel_button')
    @exit = false

    abort "Input file or output folder not defined. Please specify one ! " if output_diag.filename == nil || playlist_diag.filename == nil

    compatible = compatible_sw.active?
    justcopy = justcopy_sw.active?
    use_musicdir = use_musicdir_sw.active?
    playlist = Pathname.new(playlist_diag.filename)
    output = Pathname.new(output_diag.filename)


    compatible_sw.set_sensitive(false)
    justcopy_sw.set_sensitive(false)
    use_musicdir_sw.set_sensitive(false)
    playlist_diag.set_sensitive(false)
    output_diag.set_sensitive(false)
    run_button.set_sensitive(false)
    cancel_button.set_sensitive(true)

    abort "Cannot read file #{playlist.to_s} . Does it exist?" unless playlist.expand_path.file? && playlist.expand_path.readable?

    base_dir = playlist.expand_path.dirname if use_musicdir==false

    Dir.chdir(playlist.expand_path.dirname)
    playlist_file = File.open(playlist.expand_path)
    input = M3u8::Playlist.read(playlist_file)

    progres_part = 1.to_f/input.items.count.to_f
    input.items.each do |item|
      track_location = Pathname.new(item.segment)
      track=MusicTrack.new(track_location,base_dir)
      track.transfer(output, compatible, justcopy)
      progressbar.set_fraction(progressbar.fraction + progres_part)
      break if @exit
    end

    compatible_sw.set_sensitive(true)
    justcopy_sw.set_sensitive(true)
    use_musicdir_sw.set_sensitive(true)
    playlist_diag.set_sensitive(true)
    output_diag.set_sensitive(true)
    run_button.set_sensitive(true)
    cancel_button.set_sensitive(false)

    rescue Exception => e
      show_error(e)
      compatible_sw.set_sensitive(true)
      justcopy_sw.set_sensitive(true)
      use_musicdir_sw.set_sensitive(true)
      playlist_diag.set_sensitive(true)
      output_diag.set_sensitive(true)
      run_button.set_sensitive(true)
      cancel_button.set_sensitive(false)
  end

end

if __FILE__==$0
  # Try to do some "Localization"
  language="#{ENV['LANG']}"
  case language
  when /cs_CZ\./
    resource='playlist_transfer_cz.glade'
  else
    resource='playlist_transfer.glade'
  end

  mainwindow=PlaylistTransferGUI.new("#{File.expand_path(File.dirname(__FILE__))}/#{resource}")
  mainwindow.run
end
