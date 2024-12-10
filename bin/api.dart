import 'dart:convert';
import 'package:bcrypt/bcrypt.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;


void main() async {
  final db = await mongo.Db.create(
      'mongodb+srv://anuptwri007:UntUz0k7iDUnpOvx@cluster0.pmzek.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0');

  await db.open();
  print('Connected to MongoDB');
  final usersCollection = db.collection('users');
  final movieCollection = db.collection('movies');


  final router = Router();


  router.post('/signup', (Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    final email = data['email'];
    final password = data['password'];
    final username = data['username'];
    final phone = data['phone'];
    final photo = data['photo'];
    final address = data['address'];
    final dob = data['dob'];

    // Check if the user already exists
    final existingUser = await usersCollection.findOne(where.eq('email', email));
    if (existingUser != null) {
      return Response(400, body: jsonEncode({'message': 'User already exists'}));
    }

    // Hash the password before saving it
    final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

    // Create a new user document
    final user = {
      'email': email,
      'password': hashedPassword,
      'username': username,
      'photo': photo,
      'address': address,
      'dob': dob,
      'phone': phone,
    };
    await usersCollection.insert(user);

    return Response(201, body: jsonEncode({'message': 'User created successfully',body: jsonEncode({
      'message': 'Login successful',
      'user': {
        'email': user['email'],
        'username': user['username'],
        'photo': user['photo'],
        'address': user['address'],
        'dob': user['dob'],
        'phone': user['phone'],
      }
    })}));
  });
  router.post('/login', (Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    final email = data['email'];
    final password = data['password'];

    // Ensure the DB is open before making any operations
    await db.open();

    try {
      // Fetch user from MongoDB
      final user = await usersCollection.findOne(where.eq('email', email));
      if (user == null) {
        return Response(400, body: jsonEncode({'message': 'User not found'}));
      }

      // Check if the password matches
      final isPasswordValid = BCrypt.checkpw(password, user['password']);
      if (!isPasswordValid) {
        return Response(400, body: jsonEncode({'message': 'Invalid password'}));
      }

      // Return all user details if login is successful
      return Response(200, body: jsonEncode({
        'message': 'Login successful',
        'user': {
          'email': user['email'],
          'username': user['username'],
          // 'photo': user['photo'],
          'address': user['address'],
          'dob': user['dob'],
          'phone': user['phone'],
        }
      }));
    } catch (e) {
      // Handle any error and return internal server error
      return Response.internalServerError(body: jsonEncode({'message': 'An error occurred', 'error': e.toString()}));
    } finally {
      // Close the DB connection after the operation
      await db.close();
    }
  });
  router.post('/add-movie', (Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    final photo = data['photo'];
    final title = data['title'];
    final description = data['description'];
    final director = data['director'];
    final language = data['language'];

    final format = List<String>.from(data['format'] ?? []);
    final genre = List<String>.from(data['genre'] ?? []);
    final cast = List<String>.from(data['cast'] ?? []);
    final date = List<String>.from(data['date'] ?? []);

    // Ensure 'dateTime' is a list of maps with 'date' and 'time' keys
    final dateTime = List<Map<String, String>>.from(
      (data['dateTime'] ?? []).map((item) {
        return {
          'date': item['date'] ?? '',
          'time': item['time'] ?? ''
        };
      }),
    );

    final releaseDate = data['releaseDate'];

    final movie = {
      'photo': photo,
      'title': title,
      'description': description,
      'director': director,
      'language': language,
      'format': format,
      'genre': genre,
      'cast': cast,
      'date': date,
      'dateTime': dateTime,
      'releaseDate': releaseDate,
    };

    await movieCollection.insert(movie);

    return Response(201, body: jsonEncode({'message': 'Movie created successfully'}));
  });


  Future<Response> getUsers(Request request) async {
    // Connect to the MongoDB database
    await db.open();

    try {
      // Fetch all users from the users collection
      final users = await usersCollection.find().toList();

      // Return the list of users as JSON
      return Response.ok(jsonEncode(users), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: 'Error fetching users: $e');
    } finally {
      await db.close();
    }
  }

  router.get('/add-movie', (Request request) async {
    final queryParams = request.url.queryParameters;
    final filterDate = queryParams['date']; // Get the date from query parameter

    if (filterDate == null) {
      return Response(400, body: jsonEncode({'message': 'Date parameter is required'}));
    }

    // Fetch movies where dateTime array contains a matching date
    final filteredMovies = await movieCollection.find({
      'dateTime': {
        '\$elemMatch': {'date': filterDate}
      }
    }).toList();

    // Extract the times for the given date
    final filteredTimes = filteredMovies.map((movie) {
      final times = movie['dateTime']
          .where((entry) => entry['date'] == filterDate)
          .map((entry) => entry['time'])
          .toList();

      return {
        'title': movie['title'],
        'times': times
      };
    }).toList();

    // If no movies match the filter, return a 404 response
    if (filteredTimes.isEmpty) {
      return Response(404, body: jsonEncode({'message': 'No movies found for this date'}));
    }

    return Response(200, body: jsonEncode(filteredTimes));
  });

  router.get('/users', getUsers);




  // Handle Routes
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router);

  // Start the server
  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('Server listening at http://${server.address.host}:${server.port}');
}
