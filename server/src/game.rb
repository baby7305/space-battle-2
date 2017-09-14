# require 'awesome_print'
require 'json'
require 'oj'
require 'thread'
require 'set'
require 'drb/drb'

require_relative '../lib/core_ext'
require_relative '../lib/vec'
require_relative '../components/components'
require_relative '../systems/render_system'
require_relative '../systems/systems'
require_relative '../lib/world'
require_relative '../lib/map'
require_relative '../lib/entity_manager'
require_relative '../lib/input_cacher'
require_relative '../src/network_manager'
require_relative '../src/prefab'

class GameLogger
  require 'singleton'
  include Singleton
  def initialize
    @log_file = File.open('game-log.txt', 'w+')
  end
  def log(msg)
    @log_file.puts msg
    @log_file.flush
  end

  def self.log_game_state(em, turn)
    instance.log({turn: turn, time: Time.now.to_ms, type: :game_state, state: em.id_to_comp}.to_json)
  end

  def self.log_connection(pid, host, port)
    instance.log({time: Time.now.to_ms, type: :connection, id: pid, host: host, port: port}.to_json)
  end

  def self.log_sent(pid, data)
    instance.log({time: Time.now.to_ms, type: :to_player, id: pid, msg: data}.to_json)
  end

  def self.log_received(pid, data)
    instance.log({time: Time.now.to_ms, type: :from_player, id: pid, msg: data}.to_json)
  end
end


class RtsGame
  ASSETS = {
    dirt1: 'assets/PNG/Default size/Tile/scifiTile_41.png',
    dirt2: 'assets/PNG/Default size/Tile/scifiTile_42.png',
    tree1: 'assets/PNG/Default size/Tile/scifiTile_15.png',
    tree2: 'assets/PNG/Default size/Tile/scifiTile_16.png',
    tree3: 'assets/PNG/Default size/Tile/scifiTile_27.png',
    tree4: 'assets/PNG/Default size/Tile/scifiTile_28.png',
    tree5: 'assets/PNG/Default size/Tile/scifiTile_29.png',
    tree6: 'assets/PNG/Default size/Tile/scifiTile_30.png',
    rock1: 'assets/PNG/Default size/Environment/scifiEnvironment_12.png',

    base0: 'assets/PNG/Retina/Other/base_red.png',
    worker0: 'assets/PNG/Retina/Other/worker_red.png',
    scout0: 'assets/PNG/Retina/Other/scout_red.png',
    tank0: 'assets/PNG/Retina/Other/tank_red.png',
    laser0: 'assets/PNG/Retina/Other/laser_red.png',
    base1: 'assets/PNG/Retina/Other/base_green.png',
    worker1: 'assets/PNG/Retina/Other/worker_green.png',
    scout1: 'assets/PNG/Retina/Other/scout_green.png',
    tank1: 'assets/PNG/Retina/Other/tank_green.png',
    laser1: 'assets/PNG/Retina/Other/laser_green.png',

    small_res1: 'assets/PNG/Retina/Environment/scifiEnvironment_14.png',
    large_res1: 'assets/PNG/Retina/Environment/scifiEnvironment_15.png',
    explosion1: 'assets/PNG/Retina/Other/explosion1.png',
    explosion2: 'assets/PNG/Retina/Other/explosion2.png',
    explosion3: 'assets/PNG/Retina/Other/explosion3.png',
    explosion4: 'assets/PNG/Retina/Other/explosion4.png',
    melee1: 'assets/PNG/Retina/Other/melee1.png',
    melee2: 'assets/PNG/Retina/Other/melee2.png',
    melee3: 'assets/PNG/Retina/Other/melee3.png',
    melee4: 'assets/PNG/Retina/Other/melee4.png',

    ff_cap_down: 'assets/PNG/Retina/Other/Force-Field/FF-Cap/FF-Cap-Down.png',
    ff_cap_left: 'assets/PNG/Retina/Other/Force-Field/FF-Cap/FF-Cap-Left.png',
    ff_cap_right: 'assets/PNG/Retina/Other/Force-Field/FF-Cap/FF-Cap-Right.png',
    ff_cap_up: 'assets/PNG/Retina/Other/Force-Field/FF-Cap/FF-Cap-Up.png',
    ff_corner_1: 'assets/PNG/Retina/Other/Force-Field/FF-Corner/FF-Corner-1.png',
    ff_corner_2: 'assets/PNG/Retina/Other/Force-Field/FF-Corner/FF-Corner-2.png',
    ff_corner_3: 'assets/PNG/Retina/Other/Force-Field/FF-Corner/FF-Corner-3.png',
    ff_corner_4: 'assets/PNG/Retina/Other/Force-Field/FF-Corner/FF-Corner-4.png',
    ff_cross: 'assets/PNG/Retina/Other/Force-Field/FF-Cross/FF-Cross-All.png',
    ff_single_horizontal: 'assets/PNG/Retina/Other/Force-Field/FF-Single/FF-Single-Horizontal.png',
    ff_single_vertical: 'assets/PNG/Retina/Other/Force-Field/FF-Single/FF-Single-Vertical.png',
    ff_horizontal: 'assets/PNG/Retina/Other/Force-Field/FF-Straight/FF-Straight-Horizontal.png',
    ff_vertical: 'assets/PNG/Retina/Other/Force-Field/FF-Straight/FF-Straight-Vertical.png',
    ff_t_down: 'assets/PNG/Retina/Other/Force-Field/FF-T/FF-T-Down.png',
    ff_t_left: 'assets/PNG/Retina/Other/Force-Field/FF-T/FF-T-Left.png',
    ff_t_right: 'assets/PNG/Retina/Other/Force-Field/FF-T/FF-T-Right.png',
    ff_t_up: 'assets/PNG/Retina/Other/Force-Field/FF-T/FF-T-Up.png',

    bg_space: 'assets/PNG/Retina/Other/bg_space.jpg',
    space_block: 'assets/PNG/Retina/Other/test_space_block.png',

    tank_icon: 'assets/PNG/Retina/Other/tank_icon.png',
    scout_icon: 'assets/PNG/Retina/Other/scout_icon.png',
    worker_icon: 'assets/PNG/Retina/Other/worker_icon.png',
    kill_icon: 'assets/PNG/Retina/Other/kills_icon.png',
    rip_icon: 'assets/PNG/Retina/Other/deaths_icon.png',

    total_units_icon: 'assets/PNG/Retina/Other/total_units_icon.png',
    total_res_icon: 'assets/PNG/Retina/Other/resources_icon.png',
    bad_commands_icon: 'assets/PNG/Retina/Other/bad_commands_icon.png',
    total_commands_icon: 'assets/PNG/Retina/Other/total_commands_icon.png',
    map_icon: 'assets/PNG/Retina/Other/map_icon.png',

    explosion_sound1: 'assets/sounds/explosion1.wav',
    explosion_sound2: 'assets/sounds/explosion2.wav',
    melee_sound1: 'assets/sounds/melee1.wav',
    melee_sound2: 'assets/sounds/melee2.wav',
    harvest_sound1: 'assets/sounds/harvest1.wav',
    harvest_sound2: 'assets/sounds/harvest2.wav',
    collect_sound: 'assets/sounds/collect.wav',
    game_over_sound: 'assets/sounds/collect.wav',

    peace_music1: 'assets/music/peace1.mp3',
    peace_music2: 'assets/music/peace2.mp3',
    peace_music3: 'assets/music/peace3.mp3',
    peace_music4: 'assets/music/peace4.mp3',
    battle_music1: 'assets/music/battle1.mp3',
  }

  MAX_UPDATE_SIZE_IN_MILLIS = 500
  TURN_DURATION = 200
  TURNS_PER_SECOND = 1000/TURN_DURATION
  TILE_SIZE = 64
  SIMULATION_STEP = 20
  STEPS_PER_TURN = TURN_DURATION / SIMULATION_STEP
  STARTING_WORKERS = 6
  GAME_LENGTH_IN_MS = 300_000
  UNITS = {
    base: {
      hp: 300, # roughly 2 tanks full attack for 60 sec
      range: 2,
    },
    worker: {
      cost: 100,
      hp: 10,
      range: 2,
      speed: 1,
      attack_damage: 2,
      attack_type: :melee,
      attack_cooldown_duration: 3 * STEPS_PER_TURN,
      can_carry: true,
      create_time: 5 * STEPS_PER_TURN,
    },
    scout: {
      cost: 130,
      hp: 5,
      range: 5,
      speed: 2,
      attack_damage: 1,
      attack_type: :melee,
      attack_cooldown_duration: 3 * STEPS_PER_TURN,
      create_time: 10 * STEPS_PER_TURN,
    },
    tank: {
      cost: 150,
      hp: 20,
      range: 2,
      speed: 0.5,
      attack_damage: 4,
      attack_type: :ranged,
      attack_cooldown_duration: 7 * STEPS_PER_TURN,
      create_time: 15 * STEPS_PER_TURN,
    },
  }
  PLAYER_START_RESOURCE = UNITS[:tank][:cost] * 5

  DIR_VECS = {
    'N' => vec(0,-1),
    'S' => vec(0,1),
    'W' => vec(-1,0),
    'E' => vec(1,0),
  }

  attr_accessor :entity_manager, :render_system, :resources

  def start_sim_thread(initial_state, input_queue, output_queue)
    t = Thread.new do
      ents = initial_state
      turn_count = 0
      step_count = 0
      msgs = []
      loop do

        msgs.each do |msg|
          GameLogger.log_received(msg.connection_id, msg.data)
        end
        STEPS_PER_TURN.times do |i|
          total_time = step_count * RtsGame::SIMULATION_STEP
          input = InputSnapshot.new(nil, total_time)
          input[:messages] = msgs if i == 0
          @world.update ents, SIMULATION_STEP, input, @resources #nil
          step_count += 1
        end

        GameLogger.log_game_state(ents, turn_count)

        time_remaining = ents.first(Timer).get(Timer).ttl
        base_ents = ents.find(Base, Unit)
        if time_remaining <= 0 || base_ents.any?{|be| be.get(Unit).status == :dead}
          puts "GAME OVER!"
          @game_over = true 
          @resources[:music].values.each do |m|
            m.stop if m.playing?
          end
          @resources[:sounds][:explosion_sound1].play
          @resources[:sounds][:game_over_sound].play
        end

        @network_manager.clients.each do |player_id|
          msg = generate_message_for(ents, player_id, turn_count)
          if msg
            GameLogger.log_sent(player_id, msg)
            @network_manager.write(player_id, msg)
          end
        end
        @network_manager.flush!

        output_queue << [ents.deep_clone, msgs]

        turn_count += 1
        msgs = input_queue.pop
      end
    end
    return t
  end

  def game_over?
    @game_over
  end

  def winner
    max_score = -999
    max_player = nil
    scores.each do |id, info|
      score = info[:resources]
      alive = info[:status] != :dead
      if alive && score > max_score
        max_score = score
        max_player = id
      end
    end
    max_player
  end

  def scores
    player_scores = {}
    # TODO add other stats... units created/killed/harvested/commands sent?
    @entity_manager.each_entity(Unit, Base, PlayerOwned) do |ent|
      u,b,owner = ent.components
      player_scores[owner.id] = {resources: b.resource, status: u.status}
    end
    player_scores
  end

  include DRb::DRbUndumped
  attr_reader :input_queue, :next_turn_queue, :render_mutex
  def initialize(map:,clients:,fast:false,time:,drb_port:nil)
    @fast_mode = fast
    @time = time
    @input_queue = Queue.new
    @next_turn_queue = Queue.new
    @render_mutex = Mutex.new
    if drb_port
      @drb = DRb.start_service("druby://localhost:#{drb_port}", self)
      puts 'DRB STARTED!!!'
    end
    build_world clients, map
  end

  def start!
    return if @start # DO NOT CALL THIS TWICE!
    @start = true
    @entity_manager.remove_entity id: @instructions
    Prefab.timer(entity_manager: @entity_manager, time: @time)
    @sim_thread = start_sim_thread(@entity_manager.deep_clone, @input_queue, @next_turn_queue)
    nil
  end

  def pause!
    @start = false
    # @sim_thread.kill
    require 'pry'
    binding.pry
    @start = true
  end

  def started?
    @start
  end

  def update(delta:, input:)
    begin
      if @start && !@game_over
        if @fast_mode
          msgs = @network_manager.pop_messages_with_timeout!(RtsGame::TURN_DURATION.to_f / 1000.0)
          puts "EMPTY TURN!" if msgs.empty?
          @input_queue << msgs
          tmp, _ = @next_turn_queue.pop
          # @render_mutex.synchronize do
            @entity_manager = tmp
          # end
        else
          @turn_time ||= 0
          @turn_time += delta
          @sim_steps ||= 0

          while (@sim_steps * SIMULATION_STEP <= @turn_time) && (@sim_steps < STEPS_PER_TURN)
            input[:messages] = @input_msgs if @input_msgs
            @world.update @entity_manager, SIMULATION_STEP, input, nil #@resources
            input.delete(:messages)
            @input_msgs = nil
            @sim_steps+=1
          end

          if @sim_steps >= STEPS_PER_TURN
            @sim_steps = 0
            @input_queue << @network_manager.pop_messages_with_timeout!(0.0)
            # if everything goes well, the following line should have no effect.
            @entity_manager = @next_entity_manager if @next_entity_manager
            @next_entity_manager, msgs = @next_turn_queue.pop
            @input_msgs = msgs
            @turn_time -= TURN_DURATION
          end
        end
      end
    rescue StandardError => ex
      puts ex.inspect
      puts ex.backtrace.inspect
      raise ex
    end
  end

  def generate_message_for(entity_manager, player_id, turn_count)
    tiles = []
    units = []

    time_remaining = entity_manager.first(Timer).get(Timer).ttl
    if time_remaining <= 0
      results = {}
      base_ents = entity_manager.each_entity(Base, Unit, Health, PlayerOwned, Position) do |rec|
        results[rec.get(PlayerOwned).id] = { score: rec.get(Base).resource }
      end
      return Oj.dump({player: player_id, turn: turn_count, time: time_remaining, results: results}, mode: :compat)
    end

    base_ent = entity_manager.find(Base, Unit, Health, PlayerOwned, Position).select{|ent| ent.get(PlayerOwned).id == player_id}.first

    base_id = base_ent.id
    base_pos = base_ent.get(Position)
    base_unit = base_ent.get(Unit)
    base = base_ent.get(Base)

    tile_info = entity_manager.find(PlayerOwned, TileInfo).
      find{|ent| ent.get(PlayerOwned).id == player_id}.get(TileInfo)

    map = entity_manager.first(MapInfo).get(MapInfo)

    prev_interesting_tiles = tile_info.interesting_tiles
    interesting_tiles = Set.new
    entity_manager.each_entity(Unit, PlayerOwned, Position, Ranged) do |ent|
      u, player, pos, rang = ent.components
      if player.id == player_id && u.status != :dead
        interesting_tiles.merge(TileInfoHelper.tiles_near_unit(tile_info, u, pos, rang))
      end
    end
    tile_info.interesting_tiles = interesting_tiles
    newly_visible_tiles = interesting_tiles - prev_interesting_tiles
    no_longer_visible_tiles = prev_interesting_tiles - interesting_tiles

    dirty_tiles = TileInfoHelper.dirty_tiles(tile_info)

    ((interesting_tiles & dirty_tiles) | newly_visible_tiles).each do |i,j|
      res = MapInfoHelper.resource_at(map,i,j)
      resource_ent = entity_manager.find_by_id(res[:id], Resource, Label) if res
      tile_res = nil
      if resource_ent
        tile_res = {
          id: resource_ent.id,
          type: res[:type],
          total: resource_ent.get(Resource).total,
          value: resource_ent.get(Resource).value,
        }
      end

      tile_units = MapInfoHelper.units_at(map,i,j)
      blocked = MapInfoHelper.blocked?(map,i,j)

      TileInfoHelper.see_tile(tile_info, i, j)
      tiles << {
        visible: true,
        x: i-base_pos.tile_x,
        y: j-base_pos.tile_y,
        blocked: blocked,
        resources: tile_res,
        units: tile_units.map do |tu|
          ent = entity_manager.find_by_id(tu, Position, PlayerOwned, Unit, Health)
          pid = ent.get(PlayerOwned).id
          status = ent.get(Unit).status == :dead ? :dead : :unknown
          pid != player_id ?
          {
            id: tu,
            type: ent.get(Unit).type,
            status: status,
            player_id: pid,
            health: ent.get(Health).points,
          } : nil
        end.compact
      }
    end

    no_longer_visible_tiles.each do |i,j|
      res = MapInfoHelper.resource_at(map,i,j)
      blocked = MapInfoHelper.blocked?(map,i,j)
      tiles << {
        visible: false,
        x: i-base_pos.tile_x,
        y: j-base_pos.tile_y,
      }
    end

    if base_unit.dirty?
      units << { id: base_ent.id, player_id: player_id,
        x: 0,
        y: 0,
        status: base_unit.status,
        type: base_unit.type,
        resource: base.resource,
        health: base_ent.get(Health).points,
      }
      base_unit.dirty = false
    end

    entity_manager.each_entity(Unit, Health, PlayerOwned, Position) do |ent|
      u, health, player, pos = ent.components
      if u.dirty?
        if player.id == player_id
          res_car_result = entity_manager.find_by_id(ent.id, ResourceCarrier)
          res = res_car_result&.get(ResourceCarrier)&.resource

          attack_res = entity_manager.find_by_id(ent.id, Attack)
          attack = attack_res&.get(Attack)
          can_attack = attack&.can_attack

          speed = entity_manager.find_by_id(ent.id, Speed)&.get(Speed)&.speed
          range = entity_manager.find_by_id(ent.id, Ranged)&.get(Ranged)&.distance

          unit_info = { id: ent.id, player_id: player.id,
            x: (pos.tile_x-base_pos.tile_x),
            y: (pos.tile_y-base_pos.tile_y),
            status: u.status,
            type: u.type,
            health: health.points,
            can_attack: can_attack,

            range: range,
            speed: speed,
          }
          unit_info[:resource] = res if res
          if attack
            unit_info.merge!(
              attack_damage: attack.damage,
              attack_cooldown_duration: attack.cooldown,
              attack_cooldown: attack.current_cooldown
            )
          end

          shooter = entity_manager.find_by_id(ent.id, Shooter)
          unit_info[:attack_type] = shooter ? :ranged : :melee

          units << unit_info
          u.dirty = false
        end
      end
    end
    msg = {unit_updates: units, tile_updates: tiles}
    msg.merge!(game_info: {
      map_width: map.width,
      map_height: map.height,
      game_duration: GAME_LENGTH_IN_MS,
      turn_duration: TURN_DURATION,
      unit_info: UNITS,
    }) if turn_count == 0
    msg.merge!( player: player_id, turn: turn_count, time: time_remaining)
    Oj.dump(msg, mode: :compat)
  end

  private

  def load_map!(res, map_name)
    res[:map] = Map.load_from_file(map_name)
  end

  def build_world(clients, map_name)
    @turn_time = 0
    @resources = {}
    load_map! @resources, map_name
    @entity_manager = EntityManager.new
    @network_manager = NetworkManager.new

    clients.each do |c|
      @network_manager.connect(c[:host], c[:port])
    end

    Prefab.map(player_count: clients.size,
               player_names: clients.map{|c|c[:name]},
               entity_manager: @entity_manager,
               resources: @resources)
    @instructions = Prefab.start_instructions(entity_manager: @entity_manager)

    @world = World.new [
      CommandSystem.new,
      AttackSystem.new,
      MovementSystem.new,
      CreateSystem.new,
      TimerSystem.new,
      TimedSystem.new,
      TimedLevelSystem.new,
      SoundSystem.new,
      DeathSystem.new,
      AnimationSystem.new(fast_mode: @fast_mode),
    ]
    @render_system = RenderSystem.new
  end

end
