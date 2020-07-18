require 'test_helper'

class SessionsTest < ActionDispatch::IntegrationTest
  # TODO replace fixtures w/ factories
  # fixtures :users, :accounts
  #
  # test 'sign in through web passing correct params should succeed' do
  #   user = users(:dennis)
  #   post_via_redirect user_session_path, user: { email: user.email, password: 'testing' }, format: 'html'
  #   assert_response :success
  #   assert_equal [[user.id], user.password_salt], session['warden.user.user.key']
  # end
  #
  # test 'sign in without format should succeed' do
  #   user = users(:dennis)
  #   post_via_redirect user_session_path, user: { email: user.email, password: 'testing' }
  #   assert_response :success
  #   assert_equal [[user.id], user.password_salt], session['warden.user.user.key']
  # end
  #
  # test 'sign in through mobile passing correct params should succeed' do
  #   user = users(:dennis)
  #   post_via_redirect user_session_path, user: { email: user.email, password: 'testing' }, format: 'mobile'
  #   assert_response :success
  #   assert_equal [[user.id], user.password_salt], session['warden.user.user.key']
  # end
  #
  # test 'sign in through mobile passing mal formed params (iOS launcher) should succeed' do
  #   user = users(:dennis)
  #   post_via_redirect user_session_path, email: user.email, password: 'testing', format: 'mobile'
  #   assert_response :success
  #   assert_equal [[user.id], user.password_salt], session['warden.user.user.key']
  # end
  #
  # test 'sign out through web should succeed' do
  #   user = users(:dennis)
  #   post_via_redirect user_session_path, user: { email: user.email, password: 'testing' }, format: 'html'
  #   get destroy_user_session_path, user: { email: user.email, password: 'testing' }, format: 'html'
  #   assert_nil session['warden.user.user.key']
  # end
  #
  # test 'sign out through mobile should succeed' do
  #   user = users(:dennis)
  #   post_via_redirect user_session_path, user: { email: user.email, password: 'testing' }, format: 'mobile'
  #   get destroy_user_session_path, user: { email: user.email, password: 'testing' }, format: 'mobile'
  #   assert_nil session['warden.user.user.key']
  # end
  #
  # test 'sign in with invalid credentials should not log in the user' do
  #   user = users(:dennis)
  #   post_via_redirect user_session_path, user: { email: user.email, password: 'asdasdads' }, format: 'html'
  #   assert_response :success
  #   assert_nil session['warden.user.user.key']
  #   get user_session_path, user: { email: user.email, password: 'asdasdads' }, format: 'mobile'
  #   assert_response :success
  #   assert_nil session['warden.user.user.key']
  # end
  #
  # test 'sign out as view-only user should succeed' do
  #   user = users(:newcustomer)
  #   post_via_redirect user_session_path, user: { email: user.email, password: 'testing' }, format: 'html'
  #   assert_not session['warden.user.user.key'].nil?
  #   get destroy_user_session_path, user: { email: user.email, password: 'testing' }, format: 'html'
  #   assert_nil session['warden.user.user.key']
  # end
end
