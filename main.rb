require 'yaml'
require 'prawn'
require 'date'
require 'i18n'

require 'optparse'
require 'ostruct'

options = OpenStruct.new
OptionParser.new do |opt|
  opt.on('-c', '--cv FILENAME', 'CV filename (resume.yaml)') { |o| options.input = o }
  opt.on('-i', '--image FILENAME', 'Image filename (cv.png)') { |o| options.image = o }
  opt.on('-o', '--output FILENAME', 'The pdf output') { |o| options.output = o }
end.parse!

if options.input.nil?
	raise OptionParser::MissingArgument, "Missing input"
end


f = File.open options.input, 'r'

o = YAML.load f

work = o['work']

class HighlightCallback
	def initialize(options)
		@color = options[:color]
		@document = options[:document]
	end
	DELTA = [2, 2]
	def render_behind(fragment)
 	# @document.stroke_rounded_polygon(2, fragment.top_left, fragment.top_right, fragment.bottom_right, fragment.bottom_left)
 end
end

def date_format d
	month_names = [nil, 'jan', 'feb', 'mar', 'apr', 'maj', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'] # I18n.t("date.abbr_month_names", "sv_se")
	month_name = month_names[d.month]
	return "#{month_name}, #{d.year}"
end

def time_span_ex start, finish
	if finish.nil?
		return ""
	end
	months_between = finish.month - start.month + 12 * (finish.year - start.year)

	years = months_between / 12
	months = months_between % 12

	if months == 0
		months_string = ''
	elsif months > 1
		months_string = "#{months} månader"
	else
		months_string = "#{months} månad"
	end

	if years > 0
		if months_string.empty?
			"#{years} år"
		else
			"#{years} år, #{months_string}"
		end
	else
		"#{months_string}"
	end
end

def time_span start, finish
	t = time_span_ex start, finish
	if not t.empty?
		t = "\u2022 #{t}"
	end
	t
end

Prawn::Document.generate options.output do

	bounding_box([70, 700], :width => 400, :height => 700) do

		font "Times-Roman"

		CHAPTER_FONT_SIZE = 16
		HEADING_FONT_SIZE = 14
		NORMAL_FONT_SIZE = 11
		MINIMAL_FONT_SIZE = 9
		DEFAULT_COLOR = "444444"
		FAINT_COLOR = "EEEEEE"

		page_number = 1

		def draw_faint_horizontal_rule
			stroke_color FAINT_COLOR
			fill_color FAINT_COLOR
			stroke_horizontal_rule
			stroke_color DEFAULT_COLOR
			fill_color DEFAULT_COLOR
		end

		def draw_page_number page_number
			font_size MINIMAL_FONT_SIZE
			move_cursor_to 15
			draw_faint_horizontal_rule
			move_down 6
			text "Sida #{page_number} (8)", {align: :center}
			page_number += 1
		end

		def draw_header
			text "Peter Björklunds CV", {align: :center}
			move_down 4
			draw_faint_horizontal_rule
			move_down 20
		end

		def heading title
			# draw_faint_horizontal_rule
			move_down 10
			font_size CHAPTER_FONT_SIZE
			text title
			move_down 10
		end

		def split_all_words s
			array = s.split(/\s(?=(?:[^']|'[^']*')*$)/)

			formatted = []
			array.each do |w|
				if w[0] == "'"
					t = {text: w, styles: [:bold]}
				else
					t = {text: w, styles: [:normal]}
				end
				formatted.push t
			end

			# formatted_text formatted
			text s, {inline_format: true}
		end

		def check_for_page_break estimated_height, page_number
			if cursor < estimated_height
				page_number = draw_page_number page_number
				start_new_page
				draw_header
			end

			page_number
		end


		highlight = HighlightCallback.new(:color => 'ffff00', :document => self)
		self.line_width = 0

		stroke_color DEFAULT_COLOR
		fill_color DEFAULT_COLOR

		font_size CHAPTER_FONT_SIZE
		text "CV", {align: :center}
		font_size NORMAL_FONT_SIZE
		move_down 55

		image options.image, {scale: 0.2}# , {position: :center}
		move_down 12

		column = 80
		p = o['basics']
		y = cursor + 78
		font_size HEADING_FONT_SIZE
		draw_text p['name'], {at: [column, y]}
		y -= 15
		font_size NORMAL_FONT_SIZE
		draw_text p['birth'], {at: [column, y]}
		y -= 15
		draw_text p['location']['address'], {at: [column, y]}
		y -= 15
		draw_text p['location']['postalCode'] + " " + p['location']['city'], {at: [column, y]}
		y -= 15
		draw_text p['email'], {at: [column, y]}
		y -= 15
		draw_text p['phone'], {at: [column, y]}

		move_down 20
		text p['summary']
		move_down 20


		heading 'Arbetslivserfarenhet'

		work.each do |w|
			estimated_height = w['highlights'].count * 11 + 120
			page_number = check_for_page_break estimated_height, page_number
			line_width = 0
			# stroke_horizontal_rule
			company_name = w['company']
			position = w['position']
			font_size HEADING_FONT_SIZE
			text "#{company_name}"
			move_down 0
			font_size NORMAL_FONT_SIZE

			text "#{position}"
			move_down 2
			start_date = w['startDate']
			start_date_format = date_format start_date
			end_date_text = w['endDate']
			end_date_format = ''
			if end_date_text.nil?
			else
				end_date = end_date_text
				end_date_format = date_format end_date
			end

			time_employed = time_span start_date, end_date
			font_size MINIMAL_FONT_SIZE
			text "#{start_date_format} - #{end_date_format} #{time_employed}"
			move_down 10
			font_size NORMAL_FONT_SIZE
			# text w['summary']
			split_all_words w['summary']
			move_down 10

			font_size MINIMAL_FONT_SIZE
			hilights = w['highlights']
			hilights.each do |h|
				keyword_string = "\u2022  #{h}"
				formatted_text [{text: keyword_string, callback: highlight}]
				move_down 3
			end
			move_down 30
		end

		estimated_height = 40
		page_number = check_for_page_break estimated_height, page_number

		heading 'Språk'

		languages = o['languages']
		languages.each do |l|
			estimated_height = 100
			page_number = check_for_page_break estimated_height, page_number
			font_size HEADING_FONT_SIZE
			text l['language']

			font_size NORMAL_FONT_SIZE
			text l['fluency']
			move_down 15
		end
		move_down 10

		estimated_height = 400
		page_number = check_for_page_break estimated_height, page_number
		heading 'Kunskaper'

		skills = o['skills']
		skills.each do |s|
			estimated_height = s['keywords'].count * 10 + 100
			page_number = check_for_page_break estimated_height, page_number

			font_size HEADING_FONT_SIZE
			text s['name']
			move_down 3

			font_size NORMAL_FONT_SIZE
			text s['level']
			move_down 5

			font_size MINIMAL_FONT_SIZE
			keywords = s['keywords']
			keywords.each do |k|
				keyword_string = "\u2022  #{k}"
				text keyword_string
				move_down 3
			end
			move_down 15
		end

		heading 'Intressen'

		interests = o['interests']
		interests.each do |i|
			estimated_height = 20
			page_number = check_for_page_break estimated_height, page_number
			font_size MINIMAL_FONT_SIZE
			interest_name = i['name']
			interest_string = "\u2022  #{interest_name}"
			text interest_string
			move_down 3
		end

		draw_page_number page_number
	end
end
