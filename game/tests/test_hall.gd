extends TestCase


func _band(n: int) -> Band:
	var b := Band.new()
	b.leader = Man.new()
	b.leader.display_name = "Hrafn"
	b.leader.is_leader = true
	b.leader.id = b.next_id()
	for i in n:
		var m := Man.new()
		m.display_name = "man%d" % i
		b.add_man(m)
	return b


func test_ensure_creates_and_assigns_once() -> void:
	var r := CampaignRules.new()
	var b := _band(3)
	assert_eq(b.hall, null)
	var h := Hall.ensure(b, r)
	assert_true(b.hall == h, "assigned to band")
	assert_eq(h.seats, r.hall_base_seats)
	assert_eq(h.seating.size(), 3, "men seated in order, leader not")
	assert_true(not h.seating.has(b.leader.id))
	assert_true(Hall.ensure(b, r) == h, "same hall on second call")


func test_seating_syncs_with_band() -> void:
	var r := CampaignRules.new()
	var b := _band(3)
	var h := Hall.ensure(b, r)
	var first := h.seating[0]
	b.men[0].alive = false
	var newcomer := Man.new()
	b.add_man(newcomer)
	Hall.ensure(b, r)
	assert_true(not h.seating.has(first), "dead man leaves his seat")
	assert_eq(h.seating[h.seating.size() - 1], newcomer.id, "newcomer sits lowest")
	h.move(newcomer.id, 0)
	assert_eq(h.rank(newcomer.id), 0)


func test_benches_add_seats_and_cost_silver() -> void:
	var r := CampaignRules.new()
	var b := _band(10)
	var h := Hall.ensure(b, r)
	var log := PackedStringArray()
	assert_true(not h.is_seated(h.seating[9]), "tenth man beyond eight seats")
	b.silver = 100
	assert_true(h.build(r, CampaignTypes.Building.BENCHES, b, log))
	assert_eq(b.silver, 100 - r.building_costs[CampaignTypes.Building.BENCHES])
	assert_eq(h.seats, r.hall_base_seats + r.benches_seats)
	assert_true(h.is_seated(h.seating[9]))
	assert_true(h.build(r, CampaignTypes.Building.BENCHES, b, log), "benches can be built again")
	assert_eq(h.seats, r.hall_base_seats + 2 * r.benches_seats)


func test_build_refuses_without_silver_or_twice() -> void:
	var r := CampaignRules.new()
	var b := _band(1)
	var h := Hall.ensure(b, r)
	var log := PackedStringArray()
	b.silver = 5
	assert_true(not h.build(r, CampaignTypes.Building.SMITHY, b, log))
	assert_eq(b.silver, 5, "nothing paid")
	assert_true(not h.has(CampaignTypes.Building.SMITHY))
	b.silver = 200
	assert_true(h.build(r, CampaignTypes.Building.SMITHY, b, log))
	assert_true(h.has(CampaignTypes.Building.SMITHY))
	assert_true(not h.build(r, CampaignTypes.Building.SMITHY, b, log), "one smithy")
	assert_true(log.size() >= 3)


func test_storehouse_raises_capacity() -> void:
	var r := CampaignRules.new()
	var b := _band(1)
	var h := Hall.ensure(b, r)
	assert_eq(h.food_capacity(r), r.food_base_capacity)
	b.silver = 100
	h.build(r, CampaignTypes.Building.STOREHOUSE, b, PackedStringArray())
	assert_eq(h.food_capacity(r), r.food_base_capacity + r.storehouse_capacity)
