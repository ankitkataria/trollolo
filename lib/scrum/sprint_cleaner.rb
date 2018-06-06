module Scrum
  class SprintCleaner < TrelloService
    include ScrumBoards

    def cleanup(board_id, target_board_id, set_last_sprint_label: false)
      @board = sprint_board(board_id)
      raise "backlog list '#{@board.backlog_list_name}' not found on sprint board" unless @board.backlog_list
      @target_board = Trello::Board.find(target_board_id)
      raise "ready list '#{@settings.scrum.list_names['planning_ready']}' not found on planning board" unless target_list

      gen_burndown

      move_cards(@board.backlog_list, set_last_sprint_label, target_board_id)
      move_cards(@board.doing_list, set_last_sprint_label, target_board_id) if @board.doing_list
      move_cards(@board.qa_list, set_last_sprint_label, target_board_id) if @board.qa_list
    end

    private

    def target_list
      @target_list ||= @target_board.lists.find { |l| l.name == @settings.scrum.list_names['planning_ready'] }
    end

    def waterline_label(card)
      @board.find_waterline_label(card.labels)
    end

    def remove_waterline_label(card)
      label = waterline_label(card)
      card.remove_label(label) if label
    end

    def unplanned_label(card)
      @board.find_unplanned_label(card.labels)
    end

    def remove_unplanned_label(card)
      label = unplanned_label(card)
      card.remove_label(label) if label
    end

    def add_in_last_sprint_label(card, target_board_id)
      @label = Trello::Label.create(name: @settings.scrum.label_names['is_last_sprint'], board_id: target_board_id)
      card.add_label(@label)
    end

    def move_cards(source_list, set_last_sprint_label, target_board_id)
      source_list.cards.each do |card|
        next if @board.sticky?(card)
        puts %(moving card "#{card.name}" to list "#{target_list.name}")
        card.members.each { |member| card.remove_member(member) }
        remove_waterline_label(card)
        remove_unplanned_label(card)
        add_in_last_sprint_label(card, target_board_id) if set_last_sprint_label
        card.move_to_board(@target_board, target_list)
      end
    end

    def gen_burndown
      chart = BurndownChart.new(@settings)
      begin
        chart.update({})
        puts 'New burndown data was generated automatically.'
      rescue TrolloloError => e
        if e.message =~ /(burndown-data-)\d*.yaml' (not found)/
          puts e.message + '. Skipping automatic burndown generation.'
        end
      end
    end
  end
end
