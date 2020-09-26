|| @user_kcal['total_kcal'].to_i == 0



# post get_calorie
exist_calorie = client.exec_params(
    "SELECT * FROM calorie WHERE date = '#{today}' AND user_id = '#{user_id}'"
).to_a.first

if exist_calorie.nil?
    client.exec_params(
        "INSERT INTO calorie (total_kcal) VALUES ($1)",
        [get_calorie]
    )
else
    client.exec_params(
        "UPDATE calorie SET total_kcal = total_kcal + '#{get_calorie}' WHERE date = '#{today}' AND user_id = '#{user_id}'"
    )
end

<div>
        <% @users_weight.each do |user_weight| %>
            <p><%=user_weight['date']%></p>
            <p><%=user_weight['weight']%>kg</p>
        <% end %>
</div>

