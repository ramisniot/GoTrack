FactoryGirl.define do
  factory :geofence_polypoint do
    before :build do
      @downtown_geofence = FactoryGirl.create(:fence1)
    end

    # polypoints for Downtown geofence

    factory :p1 do
      latitude 32.7720583387
      order 1
      longitude -96.8111952996
      geofence @downtown_geofence
    end

    factory :p2 do
      latitude 32.7818006307
      order 2
      longitude -96.8117102837
      geofence @downtown_geofence
    end

    factory :p3 do
      latitude 32.7823779183
      order 3
      longitude -96.808877871
      geofence @downtown_geofence
    end

    factory :p4 do
      latitude 32.7948608447
      order 4
      longitude -96.7934283471
      geofence @downtown_geofence
    end

    factory :p5 do
      latitude 32.7849756658
      order 5
      longitude -96.7913684106
      geofence @downtown_geofence
    end

    factory :p6 do
      latitude 32.7797800949
      order 6
      longitude -96.7819270348
      geofence @downtown_geofence
    end

    factory :p7 do
      latitude 32.7750893883
      order 7
      longitude -96.7869052148
      geofence @downtown_geofence
    end

    factory :p8 do
      latitude 32.7726356895
      order 8
      longitude -96.798406527
      geofence @downtown_geofence
    end

    factory :p9 do
      latitude 32.7685941557
      order 9
      longitude -96.8046721673
      geofence @downtown_geofence
    end

    # polypoints for normal shape geofence (nsg)

    factory :nsg_p1 do
      association :geofence
      latitude 33.4824266426
      longitude -112.2507476807
      order 1
    end

    factory :nsg_p2 do
      association :geofence
      latitude 33.5259409178
      longitude -112.1484375000
      order 2
    end

    factory :nsg_p3 do
      association :geofence
      latitude 33.5081943159
      longitude -112.0069885254
      order 3
    end

    factory :nsg_p4 do
      association :geofence
      latitude 33.4469119561
      longitude -111.9403839111
      order 4
    end

    factory :nsg_p5 do
      association :geofence
      latitude 33.4234184464
      longitude -111.9451904297
      order 5
    end

    factory :nsg_p6 do
      association :geofence
      latitude 33.4360255107
      longitude -112.2047424316
      order 6
    end

    # polypoints for normal across antimeridian shape geofence (namsg)

    factory :namsg_p1 do
      association :geofence
      latitude 19.8080541281
      longitude 171.2109375000
      order 1
    end

    factory :namsg_p2 do
      association :geofence
      latitude -0.5273363048
      longitude 159.0820312500
      order 2
    end

    factory :namsg_p3 do
      association :geofence
      latitude -12.3829283385
      longitude 163.6523437500
      order 3
    end

    factory :namsg_p4 do
      association :geofence
      latitude -15.7922535704
      longitude 177.5390625000
      order 4
    end

    factory :namsg_p5 do
      association :geofence
      latitude -1.9332268265
      longitude -159.7851562500
      order 5
    end

    # polypoints for multi vertices shape geofence (mvsg)

    factory :mvsg_p1 do
      association :geofence
      latitude 53.8525266004
      longitude -104.4140625000
      order 1
    end

    factory :mvsg_p2 do
      association :geofence
      latitude 45.0890355648
      longitude -103.5351562500
      order 2
    end

    factory :mvsg_p3 do
      association :geofence
      latitude 51.3992056536
      longitude -114.2578125000
      order 3
    end

    factory :mvsg_p4 do
      association :geofence
      latitude 36.3151251475
      longitude -113.9062500000
      order 4
    end

    factory :mvsg_p5 do
      association :geofence
      latitude 36.5978891331
      longitude -97.9101562500
      order 5
    end

    factory :mvsg_p6 do
      association :geofence
      latitude 30.1451271834
      longitude -85.4296875000
      order 6
    end

    factory :mvsg_p7 do
      association :geofence
      latitude 44.4651510135
      longitude -90.0000000000
      order 7
    end

    factory :mvsg_p8 do
      association :geofence
      latitude 42.0329743324
      longitude -98.9648437500
      order 8
    end

    factory :mvsg_p9 do
      association :geofence
      latitude 53.8525266004
      longitude -96.8554687500
      order 9
    end

    # polypoints for multi vertices across antimeridian shape geofence (mvamsg)

    factory :mvamsg_p1 do
      association :geofence
      latitude 22.7559206815
      longitude 171.7382812500
      order 1
    end

    factory :mvamsg_p2 do
      association :geofence
      latitude 6.1405547825
      longitude 177.0117187500
      order 2
    end

    factory :mvamsg_p3 do
      association :geofence
      latitude 8.5810212156
      longitude 158.5546875000
      order 3
    end

    factory :mvamsg_p4 do
      association :geofence
      latitude -13.5819209005
      longitude 169.2773437500
      order 4
    end

    factory :mvamsg_p5 do
      association :geofence
      latitude 12.8974891838
      longitude -162.7734375000
      order 5
    end

    factory :mvamsg_p6 do
      association :geofence
      latitude -1.9332268265
      longitude -162.9492187500
      order 6
    end

    factory :mvamsg_p7 do
      association :geofence
      latitude 14.0939571778
      longitude -148.7109375000
      order 7
    end

    factory :mvamsg_p8 do
      association :geofence
      latitude 14.7748825065
      longitude -174.9023437500
      order 8
    end

    # polypoints for donut shape geofence (dsg)

    factory :dsg_p1 do
      association :geofence
      latitude 55.4788534633
      longitude -102.8320312500
      order 1
    end

    factory :dsg_p2 do
      association :geofence
      latitude 53.3308729830
      longitude -113.9062500000
      order 2
    end

    factory :dsg_p3 do
      association :geofence
      latitude 50.1768981220
      longitude -119.1796875000
      order 3
    end

    factory :dsg_p4 do
      association :geofence
      latitude 45.4601306379
      longitude -118.6523437500
      order 4
    end

    factory :dsg_p5 do
      association :geofence
      latitude 41.7713116798
      longitude -115.8398437500
      order 5
    end

    factory :dsg_p6 do
      association :geofence
      latitude 38.9594087925
      longitude -111.6210937500
      order 6
    end

    factory :dsg_p7 do
      association :geofence
      latitude 37.9961626797
      longitude -101.2500000000
      order 7
    end

    factory :dsg_p8 do
      association :geofence
      latitude 38.9594087925
      longitude -89.6484375000
      order 8
    end

    factory :dsg_p9 do
      association :geofence
      latitude 43.9611906389
      longitude -82.7929687500
      order 9
    end

    factory :dsg_p10 do
      association :geofence
      latitude 48.1074311885
      longitude -84.3750000000
      order 10
    end

    factory :dsg_p11 do
      association :geofence
      latitude 51.9442648790
      longitude -86.3085937500
      order 11
    end

    factory :dsg_p12 do
      association :geofence
      latitude 53.2257684358
      longitude -93.1640625000
      order 12
    end

    factory :dsg_p13 do
      association :geofence
      latitude 54.5720616557
      longitude -97.0312500000
      order 13
    end

    factory :dsg_p14 do
      association :geofence
      latitude 52.8027614154
      longitude -99.4921875000
      order 14
    end

    factory :dsg_p15 do
      association :geofence
      latitude 50.7364551370
      longitude -98.2617187500
      order 15
    end

    factory :dsg_p16 do
      association :geofence
      latitude 49.1529696562
      longitude -92.8125000000
      order 16
    end

    factory :dsg_p17 do
      association :geofence
      latitude 47.3983492004
      longitude -90.0000000000
      order 17
    end

    factory :dsg_p18 do
      association :geofence
      latitude 43.7075935041
      longitude -90.5273437500
      order 18
    end

    factory :dsg_p19 do
      association :geofence
      latitude 42.6824353984
      longitude -94.7460937500
      order 19
    end

    factory :dsg_p20 do
      association :geofence
      latitude 42.5530802890
      longitude -101.9531250000
      order 20
    end

    factory :dsg_p21 do
      association :geofence
      latitude 42.8115217451
      longitude -106.3476562500
      order 21
    end

    factory :dsg_p22 do
      association :geofence
      latitude 45.0890355648
      longitude -110.9179687500
      order 22
    end

    factory :dsg_p23 do
      association :geofence
      latitude 48.9224992638
      longitude -112.5000000000
      order 23
    end

    factory :dsg_p24 do
      association :geofence
      latitude 50.6250730634
      longitude -109.1601562500
      order 24
    end

    factory :dsg_p25 do
      association :geofence
      latitude 51.7270281570
      longitude -103.5351562500
      order 25
    end

    # polypoints for donut across antimeridian shape geofence (damsg)

    factory :damsg_p1 do
      association :geofence
      latitude 18.1458517717
      longitude 174.0234375000
      order 1
    end

    factory :damsg_p2 do
      association :geofence
      latitude 10.4878118821
      longitude 162.5976562500
      order 2
    end

    factory :damsg_p3 do
      association :geofence
      latitude 6.1405547825
      longitude 160.8398437500
      order 3
    end

    factory :damsg_p4 do
      association :geofence
      latitude -2.2845506602
      longitude 159.9609375000
      order 4
    end

    factory :damsg_p5 do
      association :geofence
      latitude -9.7956775828
      longitude 163.6523437500
      order 5
    end

    factory :damsg_p6 do
      association :geofence
      latitude -16.1302620120
      longitude 173.1445312500
      order 6
    end

    factory :damsg_p7 do
      association :geofence
      latitude -17.3086878868
      longitude -172.6171875000
      order 7
    end

    factory :damsg_p8 do
      association :geofence
      latitude -12.3829283385
      longitude -161.5429687500
      order 8
    end

    factory :damsg_p9 do
      association :geofence
      latitude 0.5273363048
      longitude -156.6210937500
      order 9
    end

    factory :damsg_p10 do
      association :geofence
      latitude 8.7547947024
      longitude -157.6757812500
      order 10
    end

    factory :damsg_p11 do
      association :geofence
      latitude 16.6361918784
      longitude -164.5312500000
      order 11
    end

    factory :damsg_p12 do
      association :geofence
      latitude 18.8127178564
      longitude -178.4179687500
      order 12
    end

    factory :damsg_p13 do
      association :geofence
      latitude 15.1145528719
      longitude 179.8242187500
      order 13
    end

    factory :damsg_p14 do
      association :geofence
      latitude 11.0059044597
      longitude -177.3632812500
      order 14
    end

    factory :damsg_p15 do
      association :geofence
      latitude 10.8333059836
      longitude -170.5078125000
      order 15
    end

    factory :damsg_p16 do
      association :geofence
      latitude 7.3624668655
      longitude -165.7617187500
      order 16
    end

    factory :damsg_p17 do
      association :geofence
      latitude 0.8788717828
      longitude -164.7070312500
      order 17
    end

    factory :damsg_p18 do
      association :geofence
      latitude -5.2660078828
      longitude -166.6406250000
      order 18
    end

    factory :damsg_p19 do
      association :geofence
      latitude -8.5810212156
      longitude -169.8046875000
      order 19
    end

    factory :damsg_p20 do
      association :geofence
      latitude -9.9688506085
      longitude -178.7695312500
      order 20
    end

    factory :damsg_p21 do
      association :geofence
      latitude -6.3152985383
      longitude 173.6718750000
      order 21
    end

    factory :damsg_p22 do
      association :geofence
      latitude -1.2303741774
      longitude 168.7500000000
      order 22
    end

    factory :damsg_p23 do
      association :geofence
      latitude 4.5654735507
      longitude 167.3437500000
      order 23
    end

    factory :damsg_p24 do
      association :geofence
      latitude 8.2332371113
      longitude 169.6289062500
      order 24
    end

    factory :damsg_p25 do
      association :geofence
      latitude 11.0059044597
      longitude 174.9023437500
      order 25
    end
  end
end
