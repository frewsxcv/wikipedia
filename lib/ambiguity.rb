# encoding: utf-8

module Maths

	@global_terms = {}

	def self.append_to_global_terms( terms )
		terms.each do |term, weight|
			if @global_terms[term]
				@global_terms[term] +=1
			else
				@global_terms.store( term, 1 )
			end
		end
	end

	def self.set_threshold(n)
		@threshold=n
	end

	def self.global_terms
		@global_terms
	end

	def self.remove_frequent_terms(h)
		h.each do |k, v|
			if @global_terms[k] < @threshold
				#h.delete(k)
			end
		end
		return h
	end

	def self.extract_terms( text )

		terms = {}

		all_terms = text.split(' ')

		all_terms.each do |term|

			['.', ',', '(', ')', '-', '"', '\''].each { |c| term.gsub!(c, '') }

			term.downcase!

			if !terms[ term ]
				terms.store( term, 0 )
			end

			terms[ term ] += 1
		end

		terms.percentages!( all_terms.size ).most_frequent

	end

	def self.compute_distance_between( text1, text2 )

		text2 = remove_frequent_terms(text2) # this is ugly

		text2.each do |k, v|
			if !text1.include?(k)
				text2.delete(k)
			end
		end

		text1.each do |k, v|
			if !text2[k]
				text2.store(k, 0.0)
			end
		end

		#pp text1
		#pp text2

		dot_product = dotp( text1, text2 )
		magnitudes = [ magnitude( text1 ), magnitude( text2 ) ]
		magnitude_p = magnitude_product( magnitudes[0], magnitudes[1] )
		return similarity( dot_product, magnitude_p )
	end

	def self.dotp(v1, v2)

		dot_product = []

		v1.values.zip(v2.values).each do |p|

			dot_product << ( p[0]*p[1] )

		end

		dot_product.inject(:+)

	end

	def self.magnitude(v)

		m = []

		v.values.each do |n|

			m << n**2

		end

		return m.inject(:+)

	end

	def self.magnitude_product(m1, m2)
		return Math.sqrt( m1 * m2 )
	end

	def self.similarity(dotp, magnitude_p)
		n = (dotp.to_f / magnitude_p.to_f)*100.0
		return n.round(2)
	end

end

module Wikipedia

	def self.do_classification( given_text, articles )
		puts "do_classification()"

		texts, terms, given_text_term_data = {}, {}, Maths::extract_terms( given_text )

		articles.each do |article_name, article|
			texts.store( article_name, article.texts.join('') )
		end

		texts.each do |article_name, text|

			text_terms = Maths::extract_terms( text )

			terms.store( article_name, text_terms )

			Maths::append_to_global_terms( text_terms )

		end

		Maths::set_threshold( Maths::global_terms.most_frequent.first[1] / 1.5 )

		results = {}

		terms.each do |article_name, term_data|
			#puts "given_text -> #{article_name}"
			d = Maths::compute_distance_between( given_text_term_data, term_data )
			if !d.nan?
			#p d
			results.store( article_name, d )
			end
			#puts
		end

		pp results.most_frequent()


		return 0
	end

	def self.disambiguate( given_text, ambiguous_article )

		reference, section_articles, other_articles = {}, {}, {}

		# extract toc and term information, load each article.

		puts "given text: #{given_text}"
		puts "ambiguous article: #{ambiguous_article.inspect}"
		puts

		ambiguous_article.sections.to_a[0, ambiguous_article.sections.size-1].each do |section|
			reference.store( section.first, section.last[ :anchor ] )
		end

		content_splits = ambiguous_article.raw_html.split("\"mw-headline\"")
		content = content_splits[1, content_splits.size-2]

		content.each do |mw|

			the_section = reference.keys[ content.index(mw) ]

			section_articles.store( the_section, {} )

			mw = "<span class=\"mw-headline\"#{mw}"

			Hpricot( mw ).search('li').each do |li|

				li.search('a').each do |a|

					href = a.attributes['href']

					if !href.include?('index.php') and !href.include?('(disambiguation)')	# we don't want the disambiguation of the disambiguation!
						section_articles[ the_section ].store( a.inner_text, { :link => href.split('/').last, :phrase => li.inner_text  } )
					end
				end

				#puts
			end
		end

		# get articles
		section_articles.each do |section, articles|
			#puts "*** #{section}"
			articles.each do |article_name, data|
				#puts "#{article_name}: \"#{data[:phrase]}\""
				other_articles.store( article_name, Wikipedia::article(article_name.dup) )
			end
			#puts
		end

		do_classification( given_text, other_articles )

	end

end
