require 'test_helper'

class ReportsHelperTest < ActionView::TestCase
  context '.minutes_to_hours' do
    context 'minutes < 60' do
      should 'return string with minutes passed' do
        assert_equal('50 min', minutes_to_hours(50))
      end
    end

    context 'minutes >= 60' do
      should 'return string with hours and minutes passed' do
        assert_equal('2 hrs, 0 min', minutes_to_hours(120))
      end
    end
  end

  context '.link_to_report' do
    should 'return link to report type' do
      expected = %{<a class=\"className" href=\"/reports\"><span>Reports Type</span></a>}
      assert_equal(expected, link_to_report('Reports Type', 'className', 'reports', 'index'))
    end
  end

  context '.is_tab_selected' do
    context 'tab is selected' do
      setup do
        params[:action] = 'index'
        params[:controller] = 'reports'
      end

      should 'return true' do
        assert(is_tab_selected?('reports', 'index'))
      end
    end

    context 'tab is not selected' do
      setup do
        params[:action] = 'scheduled reports'
        params[:controller] = 'reports'
      end

      should 'return false' do
        refute(is_tab_selected?('reports', 'index'))
      end
    end
  end

  context '.calculate_grid_classes' do
    should 'return grid classes' do
      classes = ["ui-grid-c", "ui-block-c"]
      assert_equal(classes, calculate_grid_classes)
    end
  end

  context '.report_actions' do
    context 'scheduled report' do
      context 'uncompleted report' do
        setup do
          @report = FactoryGirl.create(:scheduled_report_uncompleted)
          @report_actions = report_actions(@report)
        end

        should 'not have show action' do
          assert_no_match(/<a.*scheduled_reports\/#{@report.id}.*show.*>.*fa-eye.*<\/a>/, @report_actions)
        end

        should 'not have download action' do
          assert_no_match(/<a.*scheduled_reports\/#{@report.id}\/download.*>.*fa-download.*<\/a>/, @report_actions)
        end

        should 'have edit action' do
          assert_match(/<a.*scheduled_reports\/#{@report.id}\/edit.*>.*fa-pencil.*<\/a>/, @report_actions)
        end

        should 'have destroy action' do
          assert_match(/<a.*data-method="delete".*>.*fa-trash.*<\/a>/, @report_actions)
          assert_match(/<a.*scheduled_reports\/#{@report.id}.*>.*fa-trash.*<\/a>/, @report_actions)
        end
      end

      context 'completed report' do
        setup do
          @report = FactoryGirl.create(:scheduled_report_completed)
          @report_actions = report_actions(@report)
        end

        should 'have show action' do
          assert_match(/<a title=\"View\" href=\"\/scheduled_reports\/#{@report.id}.*/, @report_actions)
        end

        should 'have download action' do
          assert_match(/<a download=\"true\".*href=\"\/scheduled_reports\/#{@report.id}\/download.*/, @report_actions)
        end

        should 'not have edit action' do
          assert_no_match(/<a.*scheduled_reports.*#{@report.id}.*edit.*/, @report_actions)
        end

        should 'have destroy action' do
          assert_match(/<a.*data-method="delete".*>.*fa-trash.*<\/a>/, @report_actions)
          assert_match(/<a.*scheduled_reports\/#{@report.id}.*>.*fa-trash.*<\/a>/, @report_actions)
        end
      end
    end

    context 'one time report' do
      context 'uncompleted report' do
        setup do
          @report = FactoryGirl.create(:one_time_report_uncompleted)
          @report_actions = report_actions(@report)
        end

        should 'not have show action' do
          assert_no_match(/<a.*scheduled_reports\/#{@report.id}.*>.*fa-eye.*<\/a>/, @report_actions)
        end

        should 'not have download action' do
          assert_no_match(/<a.*scheduled_reports\/#{@report.id}\/download.*>.*fa-download.*<\/a>/, @report_actions)
        end

        should 'not have edit action' do
          assert_no_match(/<a.*scheduled_reports\/#{@report.id}\/edit.*>.*fa-pencil.*<\/a>/, @report_actions)
        end

        should 'not have destroy action' do
          assert_no_match(/<a.*data-method="delete".*>.*fa-trash.*<\/a>/, @report_actions)
          assert_no_match(/<a.*scheduled_reports\/#{@report.id}.*>.*fa-trash.*<\/a>/, @report_actions)
        end
      end

      context 'completed report' do
        setup do
          @report = FactoryGirl.create(:one_time_report_completed)
          @report_actions = report_actions(@report)
        end

        should 'not have show action' do
          assert_no_match(/<a.*scheduled_reports\/#{@report.id}.*>.*fa-eye.*<\/a>/, @report_actions)
        end

        should 'have download action' do
          assert_no_match(/<a.*scheduled_reports\/#{@report.id}\/download.*>.*fa-download.*<\/a>/, @report_actions)
        end

        should 'not have edit action' do
          assert_no_match(/<a.*scheduled_reports\/#{@report.id}\/edit.*>.*fa-pencil.*<\/a>/, @report_actions)
        end

        should 'not have destroy action' do
          assert_no_match(/<a.*data-method="delete".*>.*fa-trash.*<\/a>/, @report_actions)
          assert_no_match(/<a.*scheduled_reports\/#{@report.id}.*>.*fa-trash.*<\/a>/, @report_actions)
        end
      end
    end
  end

  context '.report_name' do
    context 'scheduled report' do
      context 'uncompleted report' do
        setup do
          @report = FactoryGirl.build(:scheduled_report_uncompleted)
        end

        should 'return uncompleted name' do
          assert_match(/<i class=\"fa fa-clock-o.*#{@report_report_name}/, report_name(@report))
        end
      end

      context 'completed report' do
        setup do
          @report = FactoryGirl.build(:scheduled_report_completed)
        end

        should 'return completed name' do
          assert_match(/<i class="fa fa-check.*#{@report_report_name}/, report_name(@report))
        end
      end
    end

    context 'one time report' do
      context 'uncompleted report' do
        setup do
          @report = FactoryGirl.build(:one_time_report_uncompleted)
        end

        should 'return uncompleted name' do
          assert_match(/<i class=\"fa fa-clock-o.*#{@report_report_name}/, report_name(@report))
        end
      end

      context 'completed report' do
        setup do
          @report = FactoryGirl.build(:one_time_report_completed)
        end

        should 'return completed name' do
          assert_match(/<i class="fa fa-check.*#{@report_report_name}/, report_name(@report))
        end
      end
    end
  end

  context '.for_hours' do
    should 'return hash with possible hours to select' do
      hours = for_hours
      assert_equal(24, hours.length)
      assert_equal(['for 1 hour', 1], hours[0])
      assert_equal(['for 24 hours', 24], hours[23])
    end
  end

  context '.show_map' do
    context 'when controller is reports and action is index' do
      should 'return false' do
        assert_not show_map('reports', 'index')
      end
    end

    context 'when controller is reports and action is maintenance' do
      should 'return false' do
        assert_not show_map('reports', 'maintenance')
      end
    end

    context 'when controller is reports and action is trip' do
      should 'return false' do
        assert_not show_map('reports', 'trip')
      end
    end

    context 'when controller is scheduled_reports and action is show' do
      should 'return false' do
        assert_not show_map('scheduled_reports', 'show')
      end
    end

    context 'when controller is reports and action is scheduled_reports' do
      should 'return false' do
        assert_not show_map('reports', 'scheduled_reports')
      end
    end

    context 'when controller is reports and action is idle' do
      should 'return true' do
        assert show_map('reports', 'idle')
      end
    end
  end

  context '.select_date' do
    should 'return html for selecting date' do
      date = DateTime.new(2002, 2, 3, 4, 5, 6)
      assert_match(/<select id=\"date_year\".*<select id=\"date_month\".*<select id=\"date_day\".*/m, select_date_with_arrow(date, {}, {}))
    end
  end

  context '.time_select' do
    should 'return html for selecting time (hours and minutes)' do
      assert_match(/<select id=\".*<select id=\".*/m, time_select_with_arrow(:from, {}, {}, {}))
    end
  end

  context '.geofence_name' do
    context 'geofence related reading' do
      setup do
        @reading = FactoryGirl.build(:reading_geofence_enter)
      end

      should 'return geofence name' do
        assert_equal('Downtown', geofence_name(@reading))
      end
    end

    context 'standard reading' do
      setup do
        @reading = FactoryGirl.build(:reading)
      end

      should 'return location' do
        assert_equal('location', geofence_name(@reading))
      end
    end

  end
end
