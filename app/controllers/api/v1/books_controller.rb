require 'openai'

class Api::V1::BooksController < ApplicationController
  def ask
    @book = Book.find_by!(slug: params[:book_id])
    
    render json: { completions: question.response }
  end

  private

  def question
    Question.where(query: query, book_id: @book.id).first || 
      Question.create!(query: query, response: completions, book: @book)
  end

  def completions
    return ['No results found.'] unless text_search.present?

    response = OpenAI::Client.new.completions(
      parameters: {
        model: "text-davinci-003", 
        prompt: prompt(context: text_search), 
        max_tokens: 150, 
        temperature: 0.1
      }
    )

    response["choices"].map {|c| c["text"]}
  end

  def prompt(context:)
    Query::PromptGenerationService
      .new(context: context, book: @book, query: query)
      .call
  end

  def text_search
    @text_search ||= Books::TextSearchService.new(book_id: @book.id, query: query).call
  end

  def query
    q = params.require(:query)
    q[-1].present? && q[-1] != '?' ? "#{q}?" : q 
  end
end
